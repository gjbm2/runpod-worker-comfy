#!/bin/bash

IMAGE="$1"
MAX_RETRIES="${2:-5}"  # Default to 5 retries if not specified
SLEEP_SECONDS="${3:-30}"

if [[ -z "$IMAGE" ]]; then
  echo "Usage: $0 <image-name> [max-retries] [sleep-seconds]"
  exit 1
fi

attempt=1

while true; do
  echo "Attempt $attempt: Pushing Docker image '$IMAGE'..."
  echo "Timestamp: $(date)"
  docker push "$IMAGE" && {
    echo "✅ Push succeeded on attempt $attempt"
    echo "Success timestamp: $(date)"
    break
  }

  if [[ $attempt -ge $MAX_RETRIES ]]; then
    echo "❌ Push failed after $MAX_RETRIES attempts."
    echo "Final failure timestamp: $(date)"
    exit 1
  fi

  echo "⚠️ Push failed. Retrying in $SLEEP_SECONDS seconds..."
  echo "Retry timestamp: $(date)"
  sleep "$SLEEP_SECONDS"
  ((attempt++))
done
