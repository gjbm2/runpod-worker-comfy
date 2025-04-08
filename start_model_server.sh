#!/bin/bash
set -euo pipefail

PORT=54893
SERVE_DIR="/mnt/d/dev/models"

echo "🔍 Checking if server already running on port $PORT..."

# Check if a Python HTTP server is already running on the target port
if lsof -iTCP:$PORT -sTCP:LISTEN -n | grep -q "python3"; then
    echo "✅ Server already running on port $PORT"
    exit 0
fi

echo "🚀 Starting HTTP server on port $PORT serving: $SERVE_DIR"
cd "$SERVE_DIR"

# Start the server in the background and disown it
nohup python3 -m http.server "$PORT" > /dev/null 2>&1 &
disown

echo "✅ Server started successfully"
echo "🌐 Access it at: http://localhost:$PORT/"
