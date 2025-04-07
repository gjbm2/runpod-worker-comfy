#!/bin/bash

source .venv/bin/activate

set -o allexport
source .env
set +o allexport

# echo "{$DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

DOCKER_CONFIG=$HOME/.docker-wsl docker build --build-arg MODEL_TYPE=wan2 --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-wan2 --platform linux/amd64 .
DOCKER_CONFIG=$HOME/.docker-wsl docker push gjbm2/runpod-worker-comfy:dev-wan2

DOCKER_CONFIG=$HOME/.docker-wsl docker build --build-arg MODEL_TYPE=base --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-base --platform linux/amd64 .
DOCKER_CONFIG=$HOME/.docker-wsl docker push gjbm2/runpod-worker-comfy:dev-base

DOCKER_CONFIG=$HOME/.docker-wsl docker build --build-arg MODEL_TYPE=flux1 --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-flux1 --platform linux/amd64 .
DOCKER_CONFIG=$HOME/.docker-wsl docker push gjbm2/runpod-worker-comfy:dev-flux1

DOCKER_CONFIG=$HOME/.docker-wsl docker build --build-arg MODEL_TYPE=sd35 --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-sd35 --platform linux/amd64 .
DOCKER_CONFIG=$HOME/.docker-wsl docker push gjbm2/runpod-worker-comfy:dev-sd35

DOCKER_CONFIG=$HOME/.docker-wsl docker build --build-arg MODEL_TYPE=sdxl --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-sdxl --platform linux/amd64 .
DOCKER_CONFIG=$HOME/.docker-wsl docker push gjbm2/runpod-worker-comfy:dev-sdxl
