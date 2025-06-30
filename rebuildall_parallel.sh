#!/bin/bash

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

# Create logs directory
mkdir -p logs

# Create tmux session for monitoring
SESSION_NAME="rebuildall-parallel-$$"
tmux new-session -d -s "$SESSION_NAME" -n monitor

# Build and push BASE first (sequential)
log_and_echo "=== BUILDING AND PUSHING BASE IMAGE FIRST ==="

echo "About to build BASE image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  log_and_echo "Skipping BASE image build."
else
  log_and_echo "Building BASE image..."
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=base \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-base . 2>&1 | tee -a logs/base_build.log
fi
key=""

echo "About to push BASE image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  log_and_echo "Skipping BASE image push."
else
  log_and_echo "Pushing BASE image..."
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-base 2>&1 | tee -a logs/base_push.log
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

# Build all images first (they can use BASE cache)
log_and_echo "Building all images in parallel..."
PIDS=()
for img_info in "${IMAGES[@]}"; do
  IFS=':' read -r name model_type image_tag <<< "$img_info"
  
  log_and_echo "Starting build for $name..."
  
  # Build in background
  (
    echo "About to build $name image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
    read -t 10 key
    if [[ $key == "s" ]]; then
      echo "Skipping $name image build." | tee -a "logs/${name,,}_build.log"
    else
      echo "Building $name image..." | tee -a "logs/${name,,}_build.log"
      DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
        --build-arg MODEL_TYPE="$model_type" \
        --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
        -t "$image_tag" . 2>&1 | tee -a "logs/${name,,}_build.log"
    fi
  ) &
  PIDS+=($!)
done

# Wait for all builds to complete
log_and_echo "Waiting for all builds to complete..."
for pid in "${PIDS[@]}"; do
  wait "$pid"
done
log_and_echo "All builds completed!"

# Now push all images in parallel
log_and_echo "=== STARTING PARALLEL PUSHES ==="

# Create tmux panes for monitoring
PIDS=()
for i in "${!IMAGES[@]}"; do
  img_info="${IMAGES[$i]}"
  IFS=':' read -r name model_type image_tag <<< "$img_info"
  
  log_and_echo "Starting push for $name..."
  
  # Create tmux pane for this push
  if [[ $i -eq 0 ]]; then
    tmux send-keys -t "$SESSION_NAME" "echo 'Monitoring $name push...' && tail -f logs/${name,,}_push.log" C-m
  else
    tmux split-window -t "$SESSION_NAME" -v "echo 'Monitoring $name push...' && tail -f logs/${name,,}_push.log"
    tmux select-layout -t "$SESSION_NAME" tiled > /dev/null
  fi
  
  # Push in background
  (
    echo "About to push $name image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
    read -t 10 key
    if [[ $key == "s" ]]; then
      echo "Skipping $name image push." | tee -a "logs/${name,,}_push.log"
    else
      echo "Pushing $name image..." | tee -a "logs/${name,,}_push.log"
      DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh "$image_tag" 2>&1 | tee -a "logs/${name,,}_push.log"
    fi
  ) &
  PIDS+=($!)
done

# Attach to tmux session for monitoring
log_and_echo "Attaching to monitoring session. Press Ctrl+B then D to detach."
tmux attach-session -t "$SESSION_NAME"

# Wait for all pushes to complete
log_and_echo "Waiting for all pushes to complete..."
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Clean up tmux session
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

log_and_echo "=== ALL PARALLEL BUILDS AND PUSHES COMPLETED ==="

bash stop_server.sh 