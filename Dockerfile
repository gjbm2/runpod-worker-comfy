# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8


# Add fetch_model helper
ADD fetch_model.sh /usr/local/bin/fetch_model
RUN chmod +x /usr/local/bin/fetch_model

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    libglib2.0-0 \
    git \
    wget \
    libgl1 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip
	
# Install AWS CLI v2
RUN apt-get update && apt-get install -y unzip curl && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws	

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.3.29

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install runpod
RUN pip install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add scripts
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Optionally copy the snapshot file
# ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
# RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base as downloader


# Add fetch_model helper
ADD fetch_model_2.sh /usr/local/bin/fetch_model_2
RUN chmod +x /usr/local/bin/fetch_model_2

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories
RUN mkdir -p models/checkpoints models/vae models/clip_vision models/diffusion_models models/text_encoders

# Download checkpoints/vae/LoRA to include in image based on model type

# SDXL
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
    fetch_model_2 "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" "checkpoints/sd_xl_base_1.0.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors" "vae/sdxl_vae.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors" "vae/sdxl-vae-fp16-fix.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
fi

# Wan 2.1
RUN if [ "$MODEL_TYPE" = "wan2" ]; then \
    fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "clip_vision/clip_vision_h.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    ls -lh models/clip_vision/* && \
    sync; \
fi

RUN if [ "$MODEL_TYPE" = "wan2" ]; then \
    fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "vae/wan_2.1_vae.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    ls -lh models/vae/* && \
    sync; \
fi

RUN if [ "$MODEL_TYPE" = "wan2" ]; then \
    fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors" "text_encoders/umt5_xxl_fp16.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    ls -lh models/text_encoders/* && \
    sync; \
fi

RUN if [ "$MODEL_TYPE" = "wan2" ]; then \
    #fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_720p_14B_fp16.safetensors" "diffusion_models/wan2.1_i2v_720p_14B_fp16.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_flf2v_720p_14B_fp16.safetensors" "diffusion_models/wan2.1_flf2v_720p_14B_fp16.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    
    ls -lh models/diffusion_models/* && \
    sync; \
fi

#RUN if [ "$MODEL_TYPE" = "wan2" ]; then \
#    fetch_model_2 "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp16.safetensors" "diffusion_models/wan2.1_t2v_14B_fp16.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
#fi

# SD3.5
RUN if [ "$MODEL_TYPE" = "sd35" ]; then \
    fetch_model_2 "https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors" "checkpoints/sd3.5_large.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/t5xxl_fp16.safetensors" "clip/t5xxl_fp16.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/clip_g.safetensors" "clip/clip_g.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/text_encoders/clip_l.safetensors" "clip/clip_l.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
fi

# FLUX 1 - Schnell
RUN if [ "$MODEL_TYPE" = "flux1-schnell" ]; then \
    fetch_model_2 "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors" "unet/flux1-schnell.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" "clip/clip_l.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" "clip/t5xxl_fp8_e4m3fn.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors" "vae/ae.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
fi

# FLUX 1 - Dev
RUN if [ "$MODEL_TYPE" = "flux1" ]; then \
    fetch_model_2 "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" "unet/flux1-dev.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" "clip/clip_l.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" "clip/t5xxl_fp8_e4m3fn.safetensors" "$HUGGINGFACE_ACCESS_TOKEN" && \
    fetch_model_2 "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" "vae/ae.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
fi

#
# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Go back to the root
WORKDIR /

# Optionally copy the snapshot file
ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]
