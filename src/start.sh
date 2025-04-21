#!/usr/bin/env bash

echo 
echo "Script version 11-Apr-25, 22.19"
echo 
echo "== CONTAINER INIT =="
echo 

if [ "$LIVE_PATCH" == "true" ]; then
    ## Patch image2video
    #wget -O /comfyui/comfy_extras/image2video.py https://raw.githubusercontent.com/pftq/Wan2.1-Fixes/refs/heads/main/wan/image2video.py 

    # Get laetest rp_handler script
    wget -O /rp_handler.py "https://raw.githubusercontent.com/gjbm2/runpod-worker-comfy/main/src/rp_handler.py?$(date +%s%N)" 
    wget -O /restore_snapshots.sh "https://raw.githubusercontent.com/gjbm2/runpod-worker-comfy/refs/heads/main/src/restore_snapshot.sh?$(date +%s%N)" 
    chmod +x /restore_snapshots.sh

    wget -nc -O /runpod-volume/models/diffusion_models/wan2.1_flf2v_720p_14B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_flf2v_720p_14B_fp16.safetensors

    # upgrade comfy
    cd /comfyui
    
    # Clean any local changes to avoid conflicts
    git reset --hard
    git clean -fd
    
    # Fetch all tags
    git fetch --all --tags
    
    # Checkout the specific version
    git checkout v0.3.29
    
    # Pull the latest for that tag (just in case)
    git pull origin v0.3.29
    
    # Reinstall dependencies (if needed)
    pip install -r requirements.txt

    wget 
    
fi

# Check we defintitely have the right version of rp_handler.py
if [ "$DETAILED_COMFY_LOGGING" = "true" ]; then
    head -n 1 /rp_handler.py
fi

if [ "$AWS_SYNC" == "true" ]; then
    export AWS_ACCESS_KEY_ID="$BUCKET_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$BUCKET_SECRET_ACCESS_KEY"
    export AWS_DEFAULT_REGION="$BUCKET_AWS_REGION"
    aws s3 sync s3://stable-diffusion-bucket-gjbm2/models /runpod-volume/models --no-progress --delete
    aws s3 sync s3://stable-diffusion-bucket-gjbm2/custom_nodes /runpod-volume/custom_nodes --no-progress --delete
    aws s3 sync s3://stable-diffusion-bucket-gjbm2/snapshots /runpod-volume/snapshots --no-progress --delete
fi

if [ "$COPY_MODELS" == "true" ]; then
    # copy them over for performance reasons...
    cp -v -u -r /runpod-volume/models/* /comfyui/models/
    #cp -v -u  /runpod-volume/models/diffusion_models/[NAME HERE] /comfyui/models/diffusion_models/[NAME HERE]
fi

if [ "$COPY_SNAPSHOTS" == "true" ]; then
    cp -v -u /runpod-volume/snapshots/* .
    # Try to restore nodes
    # apt update && apt install -y libglib2.0-0        # TEMP UNTIL WE HAVE RE-ROLLED CONTAINER
    /restore_snapshots.sh
    
    # pull in custom nodes
    # ln -sf /runpod-volume/custom_nodes/* /comfyui/custom_nodes 
fi

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo 
echo "== INIT COMPLETE =="
echo 

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
