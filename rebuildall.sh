#!/bin/bash

source .venv/bin/activate

set -o allexport
source .env
set +o allexport

# Optional DockerHub login (uncomment if needed)
# echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

bash start_model_server.sh

echo "WAN2"
DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
  --build-arg MODEL_TYPE=wan2 \
  --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
  -t gjbm2/runpod-worker-comfy:dev-wan2 .

DOCKER_CONFIG="$HOME/.docker-wsl" docker push gjbm2/runpod-worker-comfy:dev-wan2

echo "BASE"
DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
  --build-arg MODEL_TYPE=base \
  --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
  -t gjbm2/runpod-worker-comfy:dev-base .

DOCKER_CONFIG="$HOME/.docker-wsl" docker push gjbm2/runpod-worker-comfy:dev-base

echo "FLUX1"
DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
  --build-arg MODEL_TYPE=flux1 \
  --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
  -t gjbm2/runpod-worker-comfy:dev-flux1 .

DOCKER_CONFIG="$HOME/.docker-wsl" docker push gjbm2/runpod-worker-comfy:dev-flux1

echo "SD35"
DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
  --build-arg MODEL_TYPE=sd35 \
  --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
  -t gjbm2/runpod-worker-comfy:dev-sd35 .

DOCKER_CONFIG="$HOME/.docker-wsl" docker push gjbm2/runpod-worker-comfy:dev-sd35

echo "SDXL"
DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
  --build-arg MODEL_TYPE=sdxl \
  --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
  -t gjbm2/runpod-worker-comfy:dev-sdxl .

DOCKER_CONFIG="$HOME/.docker-wsl" docker push gjbm2/runpod-worker-comfy:dev-sdxl

bash stop_server.sh
