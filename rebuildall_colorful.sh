#!/bin/bash

# Create log directory if it doesn't exist
mkdir -p logs

# Generate timestamp for log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/rebuild_${TIMESTAMP}.log"

echo "Starting build process with colorful output..."
echo "Log file: $LOG_FILE"
echo "To monitor progress: tail -f $LOG_FILE"

# Force color output and enable BuildKit
export FORCE_COLOR=1
export DOCKER_BUILDKIT=1

# Use script to capture colors and run the build
script -q -c "bash rebuildall.sh" "$LOG_FILE"

echo "Build completed! Check the log file: $LOG_FILE" 