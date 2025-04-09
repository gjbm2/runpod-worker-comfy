#!/usr/bin/env bash

# Patch image2video
wget -O /comfyui/comfy_extras/image2video.py https://raw.githubusercontent.com/Wan-Video/Wan2.1/236dd43eddd7632566d837c6ac14f0b4337303de/wan/image2video.py 

# Get laetest rp_handler script
wget -O /rp_handler.py https://raw.githubusercontent.com/gjbm2/runpod-worker-comfy/main/src/rp_handler.py && 

echo 
echo "======================================== AWS SYNC ===="
echo 
export AWS_ACCESS_KEY_ID="$BUCKET_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BUCKET_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$BUCKET_AWS_REGION"
aws s3 sync s3://stable-diffusion-bucket-gjbm2/models /runpod-volume/models --no-progress
aws s3 sync s3://stable-diffusion-bucket-gjbm2/custom_nodes /runpod-volume/custom_nodes --no-progress
# aws s3 sync s3://stable-diffusion-bucket-gjbm2/snapshots /runpod-volume/snapshots --no-progress

if [ "$COPY_SCRIPTS" == "true" ]; then
    # copy them over for performance reasons...
    cp -v -u -r /runpod-volume/models/* /comfyui/models/
fi

# pull in custom nodes
ln -sf /runpod-volume/custom_nodes/* /comfyui/custom_nodes 

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --force-fp16 --disable-auto-launch --disable-metadata --listen &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py
fi
