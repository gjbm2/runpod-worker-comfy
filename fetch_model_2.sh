#!/usr/bin/env bash
set -euo pipefail

# --- Inputs
PORT=54893
DEST_DIR="models"
HUGGINGFACE_URL="$1"
FILENAME="$2"
HUGGINGFACE_TOKEN="${3:-}"  # Optional third argument

# --- Prepare paths
LOCAL_URL="http://host.docker.internal:$PORT/$FILENAME"
OUTPUT_PATH="$DEST_DIR/$FILENAME"

# --- Ensure destination folder exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

# --- Try to fetch from local HTTP cache first
echo "📦 Trying local cache: $LOCAL_URL"
if wget --progress=dot:giga -O "$OUTPUT_PATH" "$LOCAL_URL"; then
    echo "✅ Downloaded from local cache: $FILENAME"
else
    echo "⚠️ Local cache miss, falling back to HuggingFace..."
    if [[ -n "$HUGGINGFACE_TOKEN" ]]; then
        wget --header="Authorization: Bearer $HUGGINGFACE_TOKEN" \
             --progress=dot:giga \
             -O "$OUTPUT_PATH" \
             "$HUGGINGFACE_URL"
    else
        wget --progress=dot:giga -O "$OUTPUT_PATH" "$HUGGINGFACE_URL"
    fi
    echo "✅ Downloaded from HuggingFace: $FILENAME"
fi
