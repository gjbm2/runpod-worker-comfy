#!/bin/bash

PORT=54893

echo "🛑 Stopping HTTP server on port $PORT..."

# Find and kill the process
if lsof -ti tcp:$PORT | grep -q .; then
    lsof -ti tcp:$PORT | xargs kill
    echo "✅ Server stopped."
else
    echo "ℹ️ No server running on port $PORT."
fi
