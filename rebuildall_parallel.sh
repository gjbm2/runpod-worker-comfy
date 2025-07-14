#!/bin/bash

# Signal handling to kill all child processes on Ctrl+C
cleanup() {
    echo -e "\n\n🛑 Received interrupt signal. Cleaning up..."
    
    # Kill all background processes
    if [[ ${#PIDS[@]} -gt 0 ]]; then
        echo "Killing ${#PIDS[@]} background processes..."
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                echo "Killed process $pid"
            fi
        done
    fi
    
    # Kill any docker build/push processes
    echo "Killing docker processes..."
    pkill -f "docker build" 2>/dev/null
    pkill -f "retry-docker-push" 2>/dev/null
    
    # Kill tmux session
    if [[ -n "$SESSION_NAME" ]]; then
        echo "Killing tmux session..."
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null
    fi
    
    # Stop the model server
    echo "Stopping model server..."
    bash stop_server.sh 2>/dev/null
    
    echo "Cleanup complete. Exiting."
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Initialize global variables for cleanup
PIDS=()
SESSION_NAME=""

export DOCKER_BUILDKIT=1

source .venv/bin/activate

set -o allexport
source .env
set +o allexport

# Optional DockerHub login (uncomment if needed)
# echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

bash start_model_server.sh

# Function to log and echo
log_and_echo() {
    echo "$1" | tee -a logs/rebuildall_parallel.log
}

# Function to log only (no console output)
log_only() {
    echo "$1" >> logs/rebuildall_parallel.log
}

# Function to check if image needs rebuilding
check_image_needs_rebuild() {
    local image_tag="$1"
    local model_type="$2"
    
    log_only "Checking if $image_tag needs rebuilding..."
    
    # Check if local image exists
    if ! docker image inspect "$image_tag" >/dev/null 2>&1; then
        log_only "Local image $image_tag doesn't exist - needs build"
        return 0  # needs build
    fi
    
    # Check if remote image exists and compare with local
    if docker manifest inspect "$image_tag" >/dev/null 2>&1; then
        local local_digest=$(docker image inspect "$image_tag" --format='{{.Id}}' 2>/dev/null)
        local remote_digest=$(docker manifest inspect "$image_tag" --format='{{.Config.Digest}}' 2>/dev/null)
        
        if [[ -n "$local_digest" && -n "$remote_digest" && "$local_digest" == "$remote_digest" ]]; then
            # Local matches remote, but check if build context has new files
            local image_created=$(docker image inspect "$image_tag" --format='{{.Created}}' 2>/dev/null)
            if [[ -z "$image_created" ]]; then
                log_only "Cannot get image creation time for $image_tag - needs rebuild"
                return 0
            fi
            
            local image_timestamp=$(date -d "$image_created" +%s 2>/dev/null)
            if [[ -z "$image_timestamp" ]]; then
                log_only "Cannot parse image timestamp for $image_tag - needs rebuild"
                return 0
            fi
            
            # Check if any files in build context are newer than the image
            # Exclude git, logs, venv, and other non-build files
            local newest_file=$(find . -type f \
                -not -path "./.git/*" \
                -not -path "./logs/*" \
                -not -path "./.venv/*" \
                -not -path "./__pycache__/*" \
                -not -name "*.pyc" \
                -not -name "*.Zone.Identifier" \
                -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
            
            if [[ -n "$newest_file" && $(echo "$newest_file > $image_timestamp" | bc -l 2>/dev/null) == "1" ]]; then
                log_only "Build context has newer files than image $image_tag - needs rebuild"
                return 0  # needs build
            else
                log_only "Image $image_tag is up-to-date"
                return 1  # doesn't need build
            fi
        else
            log_only "Image $image_tag differs from remote - needs rebuild"
            return 0  # needs build
        fi
    else
        log_only "Remote image $image_tag doesn't exist - needs build"
        return 0  # needs build
    fi
}

# Create logs directory
mkdir -p logs

# Build and push BASE first (sequential)
log_and_echo "=== BUILDING AND PUSHING BASE IMAGE FIRST ==="

BASE_NEEDS_BUILD=false
BASE_NEEDS_PUSH=false

echo "About to build BASE image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  log_and_echo "Skipping BASE image build."
else
  # Check if BASE needs rebuilding
  if check_image_needs_rebuild "gjbm2/runpod-worker-comfy:dev-base" "base"; then
    BASE_NEEDS_BUILD=true
    BASE_NEEDS_PUSH=true
    log_and_echo "Building BASE image..."
    # Pull cache images (ignore failures for first build)
    DOCKER_CONFIG="$HOME/.docker-wsl" docker pull gjbm2/runpod-worker-comfy:dev-base || true
    if DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
      --build-arg MODEL_TYPE=base \
      --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
      --build-arg BUILDKIT_INLINE_CACHE=1 \
      --cache-from=gjbm2/runpod-worker-comfy:dev-base \
      -t gjbm2/runpod-worker-comfy:dev-base . 2>&1 | tee -a logs/base_build.log; then
      log_and_echo "BASE build completed successfully"
    else
      log_and_echo "ERROR: BASE build failed!"
      exit 1
    fi
  else
    log_and_echo "BASE image is up-to-date - skipping build"
  fi
fi
key=""

echo "About to push BASE image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  log_and_echo "Skipping BASE image push."
else
  # Only push if we built it or if it was already flagged as needing push
  if [[ "$BASE_NEEDS_PUSH" == "true" ]]; then
    log_and_echo "Pushing BASE image..."
    if DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-base 2>&1 | tee -a logs/base_push.log; then
      log_and_echo "BASE push completed successfully"
    else
      log_and_echo "ERROR: BASE push failed!"
      exit 1
    fi
  else
    log_and_echo "BASE image doesn't need pushing - skipping"
  fi
fi
key=""

log_and_echo "=== BASE COMPLETE - STARTING PARALLEL BUILDS ==="

# Define the other images to build and push in parallel
IMAGES=(
  "WAN2:wan2:gjbm2/runpod-worker-comfy:dev-wan2"
  "FLUX1:flux1:gjbm2/runpod-worker-comfy:dev-flux1"
  "FLUX1-KONTEXT:flux1-kontext:gjbm2/runpod-worker-comfy:dev-flux1-kontext"
  "SD35:sd35:gjbm2/runpod-worker-comfy:dev-sd35"
  "SDXL:sdxl:gjbm2/runpod-worker-comfy:dev-sdxl"
)

# Check which images need building/pushing (do this once)
log_and_echo "Checking which images need building..."
IMAGES_TO_BUILD=()
IMAGES_TO_PUSH=()

for img_info in "${IMAGES[@]}"; do
  IFS=':' read -r name model_type image_tag <<< "$img_info"
  
  if check_image_needs_rebuild "$image_tag" "$model_type"; then
    log_and_echo "✓ $name needs building"
    IMAGES_TO_BUILD+=("$img_info")
    IMAGES_TO_PUSH+=("$img_info")
  else
    log_only "Skipping $name - already up-to-date"
  fi
done

# Build phase
if [[ ${#IMAGES_TO_BUILD[@]} -eq 0 ]]; then
  log_and_echo "No images need building - all are up-to-date!"
else
  log_and_echo "Building and pushing ${#IMAGES_TO_BUILD[@]} images in parallel..."
  
  # Create tmux session for monitoring
  SESSION_NAME="rebuildall-parallel-$$"
  if ! tmux new-session -d -s "$SESSION_NAME" -n monitor 2>/dev/null; then
    log_and_echo "WARNING: Could not create tmux session. Continuing without monitoring."
    SESSION_NAME=""
  else
    log_and_echo "✓ Created tmux session for monitoring: $SESSION_NAME"
  fi
  
  PIDS=()
  
  for i in "${!IMAGES_TO_BUILD[@]}"; do
    img_info="${IMAGES_TO_BUILD[$i]}"
    IFS=':' read -r name model_type image_tag <<< "$img_info"
    
    log_and_echo "Starting build→push pipeline for $name..."
    
    # Create tmux pane for this build→push pipeline
    if [[ -n "$SESSION_NAME" ]]; then
      # Create the log files first
      touch "logs/${name,,}_pipeline.log"
      
      if [[ $i -eq 0 ]]; then
        tmux send-keys -t "$SESSION_NAME" "echo 'Monitoring $name pipeline...' && tail -f logs/${name,,}_pipeline.log" C-m
      else
        tmux split-window -t "$SESSION_NAME" -v "echo 'Monitoring $name pipeline...' && tail -f logs/${name,,}_pipeline.log" 2>/dev/null
        tmux select-layout -t "$SESSION_NAME" tiled >/dev/null 2>&1
      fi
      
      # Give tmux a moment to create the pane
      sleep 1
    fi
    
    # Build→Push pipeline in background
    (
      echo "=== STARTING $name BUILD ===" >> "logs/${name,,}_pipeline.log"
      echo "Building $name image..." >> "logs/${name,,}_pipeline.log"
      
      # Pull cache images (ignore failures for first build)
      echo "Pulling cache images..." >> "logs/${name,,}_pipeline.log"
      DOCKER_CONFIG="$HOME/.docker-wsl" docker pull "$image_tag" >> "logs/${name,,}_pipeline.log" 2>&1 || true
      
      if DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
        --build-arg MODEL_TYPE="$model_type" \
        --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --cache-from="$image_tag" \
        -t "$image_tag" . >> "logs/${name,,}_pipeline.log" 2>&1; then
        
        echo "✅ $name build completed successfully" >> "logs/${name,,}_pipeline.log"
        echo "=== STARTING $name PUSH ===" >> "logs/${name,,}_pipeline.log"
        echo "Pushing $name image..." >> "logs/${name,,}_pipeline.log"
        
        if DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh "$image_tag" >> "logs/${name,,}_pipeline.log" 2>&1; then
          echo "SUCCESS" > "logs/${name,,}_result.tmp"
          echo "✅ $name push completed successfully" >> "logs/${name,,}_pipeline.log"
          echo "🎉 $name PIPELINE COMPLETE" >> "logs/${name,,}_pipeline.log"
        else
          echo "PUSH_FAILED" > "logs/${name,,}_result.tmp"
          echo "❌ ERROR: $name push failed!" >> "logs/${name,,}_pipeline.log"
        fi
      else
        echo "BUILD_FAILED" > "logs/${name,,}_result.tmp"
        echo "❌ ERROR: $name build failed!" >> "logs/${name,,}_pipeline.log"
      fi
    ) &
    PIDS+=($!)
  done

  # Attach to tmux session for monitoring
  if [[ -n "$SESSION_NAME" ]]; then
    log_and_echo "Attaching to pipeline monitoring session. Press Ctrl+B then D to detach."
    tmux send-keys -t "$SESSION_NAME" "echo '=== PIPELINE MONITORING: Ctrl+B + arrow keys to move between panes, Ctrl+B + D to detach ==='" C-m
    tmux send-keys -t "$SESSION_NAME" "echo ''" C-m
    tmux attach-session -t "$SESSION_NAME" 2>/dev/null || log_and_echo "Could not attach to tmux session"
  fi

  # Wait for all pipelines to complete
  log_and_echo "Waiting for all build→push pipelines to complete..."
  
  # Show progress while waiting
  while [[ ${#PIDS[@]} -gt 0 ]]; do
    still_running=0
    for i in "${!PIDS[@]}"; do
      if kill -0 "${PIDS[$i]}" 2>/dev/null; then
        still_running=1
        break
      fi
    done
    
    if [[ $still_running -eq 1 ]]; then
      echo -n "."
      sleep 5
    else
      break
    fi
  done
  echo ""  # New line after progress dots
  
  # Check pipeline results
  log_and_echo "Checking pipeline results..."
  
  for pid in "${PIDS[@]}"; do
    wait "$pid"
  done
  
  # Check final results
  SUCCESS_COUNT=0
  BUILD_FAIL_COUNT=0
  PUSH_FAIL_COUNT=0
  
  for img_info in "${IMAGES_TO_BUILD[@]}"; do
    IFS=':' read -r name model_type image_tag <<< "$img_info"
    
    if [[ -f "logs/${name,,}_result.tmp" ]]; then
      result=$(cat "logs/${name,,}_result.tmp")
      rm -f "logs/${name,,}_result.tmp"
      
      case "$result" in
        "SUCCESS")
          ((SUCCESS_COUNT++))
          log_and_echo "✅ $name pipeline succeeded"
          ;;
        "BUILD_FAILED")
          ((BUILD_FAIL_COUNT++))
          log_and_echo "❌ $name build failed"
          ;;
        "PUSH_FAILED")
          ((PUSH_FAIL_COUNT++))
          log_and_echo "❌ $name push failed"
          ;;
      esac
    else
      ((BUILD_FAIL_COUNT++))
      log_and_echo "⚠️ WARNING: No result found for $name"
    fi
  done
  
  log_and_echo "Pipeline results: $SUCCESS_COUNT succeeded, $BUILD_FAIL_COUNT build failures, $PUSH_FAIL_COUNT push failures"
  
  # Clean up tmux session
  if [[ -n "$SESSION_NAME" ]]; then
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
  fi
fi

log_and_echo "=== ALL PARALLEL PIPELINES COMPLETED ==="

bash stop_server.sh

# Final summary
log_and_echo "=== FINAL SUMMARY ==="
if [[ ${#IMAGES_TO_BUILD[@]} -eq 0 && "$BASE_NEEDS_BUILD" == "false" ]]; then
  log_and_echo "No images needed rebuilding - all were up-to-date!"
else
  log_and_echo "Images processed:"
  if [[ "$BASE_NEEDS_BUILD" == "true" ]]; then
    log_and_echo "  - BASE: Built and pushed"
  fi
  for img_info in "${IMAGES_TO_BUILD[@]}"; do
    IFS=':' read -r name model_type image_tag <<< "$img_info"
    log_and_echo "  - $name: Build→push pipeline completed"
  done
fi

log_and_echo "Script completed successfully!" 