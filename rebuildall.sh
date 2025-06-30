#!/bin/bash

export DOCKER_BUILDKIT=1

source .venv/bin/activate

set -o allexport
source .env
set +o allexport

# Function to log and echo
log_and_echo() {
    echo "$1" | tee -a logs/rebuildall.log
}

# Optional DockerHub login (uncomment if needed)
# echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

bash start_model_server.sh

echo "BASE"
echo "About to build BASE image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping BASE image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=base \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-base .
fi
key=""

echo "About to push BASE image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping BASE image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-base
fi
key=""

echo "WAN2"
echo "About to build WAN2 image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping WAN2 image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=wan2 \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-wan2 .
fi
key=""

echo "About to push WAN2 image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping WAN2 image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-wan2
fi
key=""

echo "FLUX1"
echo "About to build FLUX1 image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping FLUX1 image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=flux1 \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-flux1 .
fi
key=""

echo "About to push FLUX1 image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping FLUX1 image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-flux1
fi
key=""

echo "FLUX1-KONTEXT"
echo "About to build FLUX1-KONTEXT image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping FLUX1-KONTEXT image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=flux1-kontext \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-flux1-kontext .
fi
key=""

echo "About to push FLUX1-KONTEXT image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping FLUX1-KONTEXT image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-flux1-kontext
fi
key=""

echo "SD35"
echo "About to build SD35 image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping SD35 image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=sd35 \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-sd35 .
fi
key=""

echo "About to push SD35 image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping SD35 image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-sd35
fi
key=""

echo "SDXL"
echo "About to build SDXL image. Press 's' then Enter in the next 10 seconds to skip build, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping SDXL image build."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" docker build \
    --build-arg MODEL_TYPE=sdxl \
    --build-arg HUGGINGFACE_ACCESS_TOKEN="${HUGGINGFACE_ACCESS_TOKEN}" \
    -t gjbm2/runpod-worker-comfy:dev-sdxl .
fi
key=""

echo "About to push SDXL image. Press 's' then Enter in the next 10 seconds to skip push, or wait to continue."
read -t 10 key
if [[ $key == "s" ]]; then
  echo "Skipping SDXL image push."
else
  DOCKER_CONFIG="$HOME/.docker-wsl" bash retry-docker-push.sh gjbm2/runpod-worker-comfy:dev-sdxl
fi
key=""

bash stop_server.sh
