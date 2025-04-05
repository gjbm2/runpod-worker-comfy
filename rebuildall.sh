source .venv/bin/activate

set -o allexport
source .env
set +o allexport

echo "{$DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

docker build --build-arg MODEL_TYPE=base --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-base --platform linux/amd64 .
docker push gjbm2/runpod-worker-comfy:dev-base

docker build --build-arg MODEL_TYPE=flux1 --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-flux1 --platform linux/amd64 .
docker push gjbm2/runpod-worker-comfy:dev-flux1

docker build --build-arg MODEL_TYPE=sd35 --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-sd35 --platform linux/amd64 .
docker push gjbm2/runpod-worker-comfy:dev-sd35

docker build --build-arg MODEL_TYPE=sdxl --build-arg HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN} -t gjbm2/runpod-worker-comfy:dev-sdxl --platform linux/amd64 .
docker push gjbm2/runpod-worker-comfy:dev-sdxl