#!/bin/bash

# Create log directory if it doesn't exist
mkdir -p logs

# Generate timestamp for log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/rebuild_${TIMESTAMP}.log"

echo "Starting build process in screen session..."
echo "Log file: $LOG_FILE"
echo "To monitor progress: tail -f $LOG_FILE"
echo "To attach to screen: screen -r rebuild_session"

# Start screen session with the build script
screen -dmS rebuild_session bash -c "
    # Force color output
    export FORCE_COLOR=1
    export DOCKER_BUILDKIT=0
    
    echo 'Starting rebuildall.sh at $(date)' > $LOG_FILE
    echo '==========================================' >> $LOG_FILE
    
    # Run the original script with all output to log file
    bash rebuildall.sh 2>&1 | tee -a $LOG_FILE
    
    echo '==========================================' >> $LOG_FILE
    echo 'Build completed at $(date)' >> $LOG_FILE
    
    # Keep screen session alive for a bit so you can see final output
    sleep 10
"

echo "Build started in screen session 'rebuild_session'"
echo "Monitor with: tail -f $LOG_FILE"
echo "Attach to session with: screen -r rebuild_session"
echo "Detach from session with: Ctrl+A, then D" 