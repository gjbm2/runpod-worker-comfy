#!/bin/bash

SOURCE_IMAGE="$1"        # e.g. gjbm2/runpod-worker-comfy:dev-wan2
FINAL_TAG="$2"           # e.g. gjbm2/runpod-worker-comfy:dev-final
NUM_ATTEMPTS="${3:-3}"   # Default: 3 concurrent pushes
SESSION_NAME="pushrace-$$"
SUCCESS_FLAG="/tmp/docker-push-success.$$"
LOG_DIR="/tmp/docker-push-logs-$$"

if [[ -z "$SOURCE_IMAGE" || -z "$FINAL_TAG" ]]; then
  echo "Usage: $0 <source-image> <final-tag> [num-attempts]"
  exit 1
fi

mkdir -p "$LOG_DIR"
TAG_BASE="${FINAL_TAG}-upload"

echo "🔁 Creating $NUM_ATTEMPTS variant tags..."
for i in $(seq 1 "$NUM_ATTEMPTS"); do
  TAG="${TAG_BASE}${i}"
  docker tag "$SOURCE_IMAGE" "$TAG"
done

# 🧵 Create tmux session
tmux new-session -d -s "$SESSION_NAME" -n pushrace

PIDS=()
for i in $(seq 1 "$NUM_ATTEMPTS"); do
  TAG="${TAG_BASE}${i}"
  LOG_FILE="$LOG_DIR/${TAG//\//_}.log"

  CMD="(docker push $TAG && echo $TAG > $SUCCESS_FLAG) > $LOG_FILE 2>&1"

  # Launch background push
  bash -c "$CMD" &
  PIDS+=($!)

  # Create tmux pane for this push log
  if [[ $i -eq 1 ]]; then
    tmux send-keys -t "$SESSION_NAME" "tail -f $LOG_FILE" C-m
  else
    tmux split-window -t "$SESSION_NAME" -v "tail -f $LOG_FILE"
    tmux select-layout -t "$SESSION_NAME" tiled > /dev/null
  fi
done

# 🕒 Attach session for the user to watch
tmux select-pane -t "$SESSION_NAME":0.0
tmux attach-session -t "$SESSION_NAME" &

# 🕵️‍♂️ Wait for one to succeed
echo "🕒 Waiting for first successful push to finish..."
while [ ! -f "$SUCCESS_FLAG" ]; do
  sleep 1
done

WINNER_TAG=$(cat "$SUCCESS_FLAG")
echo -e "\n🏁 Success: $WINNER_TAG"

# 🧼 Kill others
echo "🧹 Cleaning up..."
for pid in "${PIDS[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
  fi
done

tmux kill-session -t "$SESSION_NAME"
sleep 1

# 🔁 Final tag and push
echo "🔁 Retagging as $FINAL_TAG"
docker tag "$WINNER_TAG" "$FINAL_TAG"
docker push "$FINAL_TAG"

# 🧹 Cleanup
rm -f "$SUCCESS_FLAG"
rm -rf "$LOG_DIR"

echo "✅ Done. Final image tag: $FINAL_TAG"
