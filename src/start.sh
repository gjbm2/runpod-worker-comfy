#!/usr/bin/env bash

which aws
export PATH=$HOME/.local/bin:$PATH
echo "Try to sync S3"
export AWS_ACCESS_KEY_ID="$BUCKET_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BUCKET_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$BUCKET_AWS_REGION"
aws s3 sync s3://stable-diffusion-bucket-gjbm2/models /runpod-volume/models

echo ""
echo "======================================== VOLUME FILES ===="
echo ""
find /runpod-volume/ -type f
echo ""
echo "======================================== ENDS ===="
echo ""

mkdir -p /comfyui/models/checkpoints
ln -sf /runpod-volume/models/checkpoints/* /comfyui/models/checkpoints
ls -l /comfyui/models/checkpoints
mkdir -p /comfyui/models/unet
ln -sf /runpod-volume/models/unet/* /comfyui/models/unet
ls -l /comfyui/models/unet
mkdir -p /comfyui/models/clip
ln -sf /runpod-volume/models/clip/* /comfyui/models/clip
ls -l /comfyui/models/clip
mkdir -p /comfyui/models/vae
ln -sf /runpod-volume/models/vae/* /comfyui/models/vae
ls -l /comfyui/models/vae

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
