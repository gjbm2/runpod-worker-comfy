#!/usr/bin/env bash

echo ""
echo "======================================== VOLUME FILES ===="
echo ""
find /runpod-volume/ -type f
echo ""
echo "======================================== ENDS ===="
echo ""

mkdir /comfyui/models/checkpoints
ln -sf /runpod-volume/models/checkpoints/* /comfyui/models/checkpoints
mkdir /comfyui/models/unet
ln -sf /runpod-volume/models/unet/* /comfyui/models/unet
mkdir /comfyui/models/clip
ln -sf /runpod-volume/models/clip/* /comfyui/models/clip
mkdir /comfyui/models/vae
ln -sf /runpod-volume/models/vae/* /comfyui/models/vae

echo ""
echo "======================================== COMFY FILES ===="
echo ""
find /comfyui/ -type f
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
