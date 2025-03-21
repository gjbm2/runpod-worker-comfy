#!/usr/bin/env bash

echo 
echo "======================================== AWS SYNC ===="
echo 
export AWS_ACCESS_KEY_ID="$BUCKET_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BUCKET_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$BUCKET_AWS_REGION"
aws s3 sync s3://stable-diffusion-bucket-gjbm2/models /runpod-volume/models --no-progress
aws s3 sync s3://stable-diffusion-bucket-gjbm2/custom_nodes /runpod-volume/custom_nodes --no-progress
# aws s3 sync s3://stable-diffusion-bucket-gjbm2/snapshots /runpod-volume/snapshots --no-progress

echo ""
echo "======================================== VOLUME FILES ===="
echo ""
find /runpod-volume/ -type f
echo ""
echo "======================================== ENDS ===="
echo ""

#SRC="/runpod-volume/models"
#DEST="/comfyui/models"
## Create missing directories
#find "$SRC" -type d -exec mkdir -p "$DEST/{}" \;
## Create symlinks for missing files (relative paths)
#find "$SRC" -type f ! -exec test -e "$DEST/$(realpath --relative-to="$SRC" "{}")" \; -exec ln -s "{}" "$DEST/$(realpath --relative-to="$SRC" "{}")" \;

SRC="/runpod-volume/custom_nodes"
DEST="/comfyui/custom_nodes"
# Create missing directories
find "$SRC" -type d -exec mkdir -p "$DEST/$(realpath --relative-to="$SRC" "{}")" \;
# Create symlinks for missing or outdated files
find "$SRC" -type f -exec ln -sf "{}" "$DEST/$(realpath --relative-to="$SRC" "{}")" \;

SRC="/runpod-volume/models"
DEST="/comfyui/models"
# Create missing directories
find "$SRC" -type d -exec mkdir -p "$DEST/$(realpath --relative-to="$SRC" "{}")" \;
# Create symlinks for missing or outdated files
find "$SRC" -type f -exec ln -sf "{}" "$DEST/$(realpath --relative-to="$SRC" "{}")" \;

#find /runpod-volume/models/ -type d -exec mkdir -p /comfyui/models/{} \;
#find /runpod-volume/models/ -type f ! -exec test -e /comfyui/models/{} \; -exec ln -s {} /comfyui/models/{} \;
#find /runpod-volume/custom_nodes/ -type d -exec mkdir -p /comfyui/custom_nodes/{} \;
#find /runpod-volume/custom_nodes/ -type f ! -exec test -e /comfyui/custom_nodes/{} \; -exec ln -s {} /comfyui/custom nodes/{} \;

#ln -s /runpod-volume/custom_nodes/* /comfyui/custom_nodes

#ln -s /runpod-volume/models/* /comfyui/models
#mkdir -p /comfyui/models/checkpoints
#ln -s /runpod-volume/models/checkpoints/* /comfyui/models/checkpoints
#ls -l /comfyui/models/checkpoints
#mkdir -p /comfyui/models/unet
#ln -s /runpod-volume/models/unet/* /comfyui/models/unet
#ls -l /comfyui/models/unet
#mkdir -p /comfyui/models/clip
#ln -s /runpod-volume/models/clip/* /comfyui/models/clip
#ls -l /comfyui/models/clip
#mkdir -p /comfyui/models/vae
#ln -s /runpod-volume/models/vae/* /comfyui/models/vae
#ls -l /comfyui/models/vae
#mkdir -p /comfyui/models/loras
#ln -s /runpod-volume/models/loras/* /comfyui/models/loras
#ls -l /comfyui/models/loras

echo ""
echo "======================================== COMFY FILES ===="
echo ""
find /comfyui/ -type f
find /comfyui/ -type l -exec ls -l {} +
echo ""
echo "======================================== ENDS ===="
echo ""

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata --listen &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py
fi
