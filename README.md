# runpod-worker-comfy

> [ComfyUI](https://github.com/comfyanonymous/ComfyUI) as a serverless API on [RunPod](https://www.runpod.io/)

<p align="center">
  <img src="assets/worker_sitting_in_comfy_chair.jpg" title="Worker sitting in comfy chair" />
</p>

[![RunPod](https://api.runpod.io/badge/blib-la/runpod-worker-comfy)](https://www.runpod.io/console/hub/blib-la/runpod-worker-comfy)

[![Discord](https://img.shields.io/discord/1091306623819059300?color=7289da&label=Discord&logo=discord&logoColor=fff&style=for-the-badge)](https://discord.com/invite/m3TBB9XEkb)

---

<!-- toc -->

- [Quickstart](#quickstart)
- [Features](#features)
- [Config](#config)
  * [Environment Variables](#environment-variables)
  * [Upload image to AWS S3](#upload-image-to-aws-s3)
- [Use the Docker image on RunPod](#use-the-docker-image-on-runpod)
  * [Create your template (optional)](#create-your-template-optional)
  * [Create your endpoint](#create-your-endpoint)
  * [GPU recommendations](#gpu-recommendations)
- [API specification](#api-specification)
  * [JSON Request Body](#json-request-body)
  * [Fields](#fields)
    + ["input.images"](#inputimages)
- [Interact with your RunPod API](#interact-with-your-runpod-api)
  * [Health status](#health-status)
  * [Generate an image](#generate-an-image)
    + [Example request for SDXL with cURL](#example-request-for-sdxl-with-curl)
- [How to get the workflow from ComfyUI?](#how-to-get-the-workflow-from-comfyui)
- [Bring Your Own Models and Nodes](#bring-your-own-models-and-nodes)
  * [Network Volume](#network-volume)
  * [Custom Docker Image](#custom-docker-image)
    + [Adding Custom Models](#adding-custom-models)
    + [Adding Custom Nodes](#adding-custom-nodes)
    + [Building the Image](#building-the-image)
- [Local testing](#local-testing)
  * [Setup](#setup)
    + [Setup for Windows](#setup-for-windows)
  * [Testing the RunPod handler](#testing-the-runpod-handler)
  * [Local API](#local-api)
    + [Access the local Worker API](#access-the-local-worker-api)
    + [Access local ComfyUI](#access-local-comfyui)
- [Development and Build Scripts](#development-and-build-scripts)
  * [rebuildall.sh](#rebuildallsh)
  * [rebuildall_screen.sh](#rebuildall_screensh)
- [Automatically deploy to Docker hub with GitHub Actions](#automatically-deploy-to-docker-hub-with-github-actions)
- [Acknowledgments](#acknowledgments)

<!-- tocstop -->

---

## Quickstart

- 🐳 Choose one of the available images for your serverless endpoint:
  - `gjbm2/runpod-worker-comfy:dev-base`: Clean ComfyUI installation without pre-loaded models
  - `gjbm2/runpod-worker-comfy:dev-sdxl`: Contains Stable Diffusion XL models
  - `gjbm2/runpod-worker-comfy:dev-sd35`: Contains Stable Diffusion 3.5 Large models
  - `gjbm2/runpod-worker-comfy:dev-flux1`: Contains FLUX.1 Dev models
  - `gjbm2/runpod-worker-comfy:dev-flux1-kontext`: Contains FLUX.1 Kontext models
  - `gjbm2/runpod-worker-comfy:dev-wan2`: Contains Wan 2.1 video generation models
- ℹ️ [Use the Docker image on RunPod](#use-the-docker-image-on-runpod)
- 🧪 Pick an [example workflow](./test_resources/workflows/) & [send it to your deployed endpoint](#interact-with-your-runpod-api)

## Features

- Run any [ComfyUI](https://github.com/comfyanonymous/ComfyUI) workflow to generate images or videos
- Provide input images as base64-encoded string
- The generated content is either:
  - Returned as base64-encoded string (default)
  - Uploaded to AWS S3 ([if AWS S3 is configured](#upload-image-to-aws-s3))
- **WebSocket Integration**: Real-time progress monitoring and logging with backend relay support
- **Live Patching**: Automatic updates of handler and ComfyUI components during container startup
- **AWS S3 Sync**: Automatic synchronization of models, custom nodes, and snapshots from S3
- **Video Support**: Enhanced support for video generation workflows (MP4, WebM, WebP)
- **Multiple Model Types**: Pre-built images with various AI models:
  - **SDXL**: Stable Diffusion XL with optimized VAE
  - **SD3.5**: Stable Diffusion 3.5 Large with text encoders
  - **FLUX.1**: FLUX.1 Dev and Kontext variants
  - **Wan 2.1**: Video generation models for image-to-video workflows
- **Flexible Model Management**: Copy models from network volumes or sync from S3
- **Enhanced Logging**: Detailed logging with configurable verbosity
- **Worker Restart Control**: Programmatic worker restart with target worker selection
- Based on [Ubuntu + NVIDIA CUDA](https://hub.docker.com/r/nvidia/cuda)

## Config

### Environment Variables

| Environment Variable        | Description                                                                                                                                                                           | Default  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `REFRESH_WORKER`            | When you want to stop the worker after each finished job to have a clean state, see [official documentation](https://docs.runpod.io/docs/handler-additional-controls#refresh-worker). | `false`  |
| `COMFY_POLLING_INTERVAL_MS` | Time to wait between poll attempts in milliseconds.                                                                                                                                   | `1000`   |
| `COMFY_POLLING_MAX_RETRIES` | Maximum number of poll attempts. This should be increased the longer your workflow is running.                                                                                        | `100000` |
| `SERVE_API_LOCALLY`         | Enable local API server for development and testing. See [Local Testing](#local-testing) for more details.                                                                            | disabled |
| `DETAILED_COMFY_LOGGING`    | Enable detailed logging for debugging and monitoring. Shows workflow inputs, WebSocket messages, and processing details.                                                              | `true`   |
| `LIVE_PATCH`                | Enable automatic patching of rp_handler.py and ComfyUI components during container startup.                                                                                           | `false`  |
| `AWS_SYNC`                  | Enable automatic synchronization of models, custom nodes, and snapshots from AWS S3.                                                                                                  | `false`  |
| `COPY_MODELS`               | Copy models from network volume to local storage for improved performance.                                                                                                             | `false`  |
| `COPY_SNAPSHOTS`            | Copy and restore ComfyUI snapshots from network volume.                                                                                                                                | `false`  |
| `BACKEND_WS_URL`            | WebSocket URL for relaying ComfyUI progress messages to external backend.                                                                                                              | `ws://185.254.136.244:8765/` |
| `COMFY_OUTPUT_PATH`         | Path where ComfyUI stores generated images and videos.                                                                                                                                 | `/comfyui/output` |

### Performance Optimization Variables

| Environment Variable | Description | Default |
| --- | --- | --- |
| `REFRESH_WORKER` | Set to `false` to keep workers alive for reuse (RunPod handles reuse automatically) | `false` |

### Worker Reuse Strategy

**RunPod serverless automatically reuses workers** when they're available within the idle timeout period.

**For optimal performance:**

1. **Set `REFRESH_WORKER=false`** to keep workers alive after job completion
2. **Use batch processing** to maximize worker reuse
3. **No client-side changes needed** - RunPod infrastructure handles worker selection automatically

**Performance Benefits:**
- **Cold Start**: ~11 seconds (models load from disk)
- **Warm Start**: ~2-3 seconds (models already in GPU memory)
- **Improvement**: 70-80% faster for subsequent jobs

### Custom Node Optimization

Based on workflow analysis, the following custom nodes are **installed but unused** and can be removed to reduce startup time:

**Unused Custom Nodes:**
- `ComfyUI-DepthAnythingV2` - Depth estimation nodes
- `comfyui-fitsize` - Image resizing utilities  
- `ComfyUI_IPAdapter_plus` - IP-Adapter integration
- `comfyui-kjnodes` - Various utility nodes
- `comfyui_controlnet_aux` - ControlNet auxiliary nodes (has dependency issues)

**Used Custom Nodes (keep these):**
- `comfyui_essentials` - Provides upscaling and image resize nodes
- `ComfyUI-VideoHelperSuite` - Video processing nodes
- `ComfyUI-Frame-Interpolation` - Frame interpolation for videos

To remove unused nodes, edit the snapshot file and remove the corresponding entries from `git_custom_nodes` and `cnr_custom_nodes` sections.

### Upload image to AWS S3

This is only needed if you want to upload the generated picture to AWS S3. If you don't configure this, your image will be exported as base64-encoded string.

- Create a bucket in region of your choice in AWS S3 (`BUCKET_ENDPOINT_URL`)
- Create an IAM that has access rights to AWS S3
- Create an Access-Key (`BUCKET_ACCESS_KEY_ID` & `BUCKET_SECRET_ACCESS_KEY`) for that IAM
- Configure these environment variables for your RunPod worker:

| Environment Variable       | Description                                             | Example                                      |
| -------------------------- | ------------------------------------------------------- | -------------------------------------------- |
| `BUCKET_ENDPOINT_URL`      | The endpoint URL of your S3 bucket.                     | `https://<bucket>.s3.<region>.amazonaws.com` |
| `BUCKET_ACCESS_KEY_ID`     | Your AWS access key ID for accessing the S3 bucket.     | `AKIAIOSFODNN7EXAMPLE`                       |
| `BUCKET_SECRET_ACCESS_KEY` | Your AWS secret access key for accessing the S3 bucket. | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`   |
| `BUCKET_AWS_REGION`        | AWS region for S3 bucket (used with AWS_SYNC).          | `us-east-1`                                  |

## Use the Docker image on RunPod

### Create your template (optional)

- Create a [new template](https://runpod.io/console/serverless/user/templates) by clicking on `New Template`
- In the dialog, configure:
  - Template Name: `runpod-worker-comfy` (it can be anything you want)
  - Template Type: serverless (change template type to "serverless")
  - Container Image: `gjbm2/runpod-worker-comfy:dev-<model_type>` where `<model_type>` is one of: `base`, `sdxl`, `sd35`, `flux1`, `flux1-kontext`, `wan2`
  - Container Registry Credentials: You can leave everything as it is, as this repo is public
  - Container Disk: `20 GB` (increase for larger models like FLUX.1 or Wan 2.1)
  - (optional) Environment Variables: [Configure S3](#upload-image-to-aws-s3) and other options
- Click on `Save Template`

### Create your endpoint

- Navigate to [`Serverless > Endpoints`](https://www.runpod.io/console/serverless/user/endpoints) and click on `New Endpoint`
- In the dialog, configure:

  - Endpoint Name: `comfy`
  - Worker configuration: Select a GPU that can run the model you have chosen (see [GPU recommendations](#gpu-recommendations))
  - Active Workers: `0` (whatever makes sense for you)
  - Max Workers: `3` (whatever makes sense for you)
  - GPUs/Worker: `1`
  - Idle Timeout: `5` (you can leave the default)
  - Flash Boot: `enabled` (doesn't cost more, but provides faster boot of our worker, which is good)
  - Select Template: `runpod-worker-comfy` (or whatever name you gave your template)
  - (optional) Advanced: If you are using a Network Volume, select it under `Select Network Volume`. Otherwise leave the defaults.

- Click `deploy`
- Your endpoint will be created, you can click on it to see the dashboard

### GPU recommendations

| Model                     | Image           | Minimum VRAM Required | Container Size | Notes |
| ------------------------- | --------------- | --------------------- | -------------- | ----- |
| Base (no models)          | `dev-base`      | 4 GB                  | 10 GB          | For custom workflows |
| Stable Diffusion XL       | `dev-sdxl`      | 8 GB                  | 15 GB          | Includes optimized VAE |
| Stable Diffusion 3.5 Large| `dev-sd35`      | 12 GB                 | 20 GB          | Large text encoders |
| FLUX.1 Dev                | `dev-flux1`     | 24 GB                 | 30 GB          | High VRAM requirement |
| FLUX.1 Kontext            | `dev-flux1-kontext` | 24 GB             | 30 GB          | Context-aware variant |
| Wan 2.1 (Video)           | `dev-wan2`      | 40 GB                 | 50 GB          | Video generation models |

## API specification

The following describes which fields exist when doing requests to the API. We only describe the fields that are sent via `input` as those are needed by the worker itself. For a full list of fields, please take a look at the [official documentation](https://docs.runpod.io/docs/serverless-usage).

### JSON Request Body

```json
{
  "input": {
    "workflow": {},
    "images": [
      {
        "name": "example_image_name.png",
        "image": "base64_encoded_string"
      }
    ]
  }
}
```

### Fields

| Field Path       | Type   | Required | Description                                                                                                                               |
| ---------------- | ------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `input`          | Object | Yes      | The top-level object containing the request data.                                                                                         |
| `input.workflow` | Object | Yes      | Contains the ComfyUI workflow configuration.                                                                                              |
| `input.images`   | Array  | No       | An array of images. Each image will be added into the "input"-folder of ComfyUI and can then be used in the workflow by using it's `name` |

#### "input.images"

An array of images, where each image should have a different name.

🚨 The request body for a RunPod endpoint is 10 MB for `/run` and 20 MB for `/runsync`, so make sure that your input images are not super huge as this will be blocked by RunPod otherwise, see the [official documentation](https://docs.runpod.io/docs/serverless-endpoint-urls)

| Field Name | Type   | Required | Description                                                                              |
| ---------- | ------ | -------- | ---------------------------------------------------------------------------------------- |
| `name`     | String | Yes      | The name of the image. Please use the same name in your workflow to reference the image. |
| `image`    | String | Yes      | A base64 encoded string of the image.                                                    |

## Interact with your RunPod API

1. **Generate an API Key**:

   - In the [User Settings](https://www.runpod.io/console/serverless/user/settings), click on `API Keys` and then on the `API Key` button.
   - Save the generated key somewhere safe, as you will not be able to see it again when you navigate away from the page.

2. **Use the API Key**:

   - Use cURL or any other tool to access the API using the API key and your Endpoint ID:
     - Replace `<api_key>` with your key.

3. **Use your Endpoint**:
   - Replace `<endpoint_id>` with the [ID of the endpoint](https://www.runpod.io/console/serverless). (You can find the endpoint ID by clicking on your endpoint; it is written underneath the name of the endpoint at the top and also part of the URLs shown at the bottom of the first box.)

![How to find the EndpointID](./assets/my-endpoint-with-endpointID.png)

### Health status

```bash
curl -H "Authorization: Bearer <api_key>" https://api.runpod.ai/v2/<endpoint_id>/health
```

### Generate an image

You can either create a new job async by using `/run` or a sync by using `/runsync`. The example here is using a sync job and waits until the response is delivered.

The API expects a [JSON in this form](#json-request-body), where `workflow` is the [workflow from ComfyUI, exported as JSON](#how-to-get-the-workflow-from-comfyui) and `images` is optional.

Please also take a look at the [test_input.json](./test_input.json) to see how the API input should look like.

#### Example request for SDXL with cURL

```bash
curl -X POST -H "Authorization: Bearer <api_key>" -H "Content-Type: application/json" -d '{"input":{"workflow":{"3":{"inputs":{"seed":1337,"steps":20,"cfg":8,"sampler_name":"euler","scheduler":"normal","denoise":1,"model":["4",0],"positive":["6",0],"negative":["7",0],"latent_image":["5",0]},"class_type":"KSampler"},"4":{"inputs":{"ckpt_name":"sd_xl_base_1.0.safetensors"},"class_type":"CheckpointLoaderSimple"},"5":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"6":{"inputs":{"text":"beautiful scenery nature glass bottle landscape, purple galaxy bottle,","clip":["4",1]},"class_type":"CLIPTextEncode"},"7":{"inputs":{"text":"text, watermark","clip":["4",1]},"class_type":"CLIPTextEncode"},"8":{"inputs":{"samples":["3",0],"vae":["4",2]},"class_type":"VAEDecode"},"9":{"inputs":{"filename_prefix":"ComfyUI","images":["8",0]},"class_type":"SaveImage"}}}}' https://api.runpod.ai/v2/<endpoint_id>/runsync
```

Example response with AWS S3 bucket configuration

```json
{
  "delayTime": 2188,
  "executionTime": 2297,
  "id": "sync-c0cd1eb2-068f-4ecf-a99a-55770fc77391-e1",
  "output": {
    "message": "https://bucket.s3.region.amazonaws.com/10-23/sync-c0cd1eb2-068f-4ecf-a99a-55770fc77391-e1/c67ad621.png",
    "status": "success"
  },
  "status": "COMPLETED"
}
```

Example response as base64-encoded image

```json
{
  "delayTime": 2188,
  "executionTime": 2297,
  "id": "sync-c0cd1eb2-068f-4ecf-a99a-55770fc77391-e1",
  "output": { "message": "base64encodedimage", "status": "success" },
  "status": "COMPLETED"
}
```

## How to get the workflow from ComfyUI?

- Open ComfyUI in the browser
- Open the `Settings` (gear icon in the top right of the menu)
- In the dialog that appears configure:
  - `Enable Dev mode Options`: enable
  - Close the `Settings`
- In the menu, click on the `Save (API Format)` button, which will download a file named `workflow_api.json`

You can now take the content of this file and put it into your `workflow` when interacting with the API.

## Bring Your Own Models and Nodes

### Network Volume

Using a Network Volume allows you to store and access custom models:

1. **Create a Network Volume**:
   - Follow the [RunPod Network Volumes guide](https://docs.runpod.io/pods/storage/create-network-volumes) to create a volume.
2. **Populate the Volume**:

   - Create a temporary GPU instance:
     - Navigate to `Manage > Storage`, click `Deploy` under the volume, and deploy any GPU or CPU instance.
     - Navigate to `Manage > Pods`. Under the new pod, click `Connect` to open a shell (either via Jupyter notebook or SSH).
   - Populate the volume with your models:
     ```bash
     cd /workspace
     for i in checkpoints clip clip_vision configs controlnet embeddings loras upscale_models vae; do mkdir -p models/$i; done
     wget -O models/checkpoints/sd_xl_turbo_1.0_fp16.safetensors https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0_fp16.safetensors
     ```

3. **Delete the Temporary GPU Instance**:

   - Once populated, [terminate the temporary GPU instance](https://docs.runpod.io/docs/pods#terminating-a-pod).

4. **Configure Your Endpoint**:
   - Use the Network Volume in your endpoint configuration:
     - Either create a new endpoint or update an existing one.
     - In the endpoint configuration, under `Advanced > Select Network Volume`, select your Network Volume.
   - **Enable Model Copying**: Set `COPY_MODELS=true` to copy models from the network volume to local storage for better performance.

Note: The folders in the Network Volume are automatically available to ComfyUI when the network volume is configured and attached.

### Custom Docker Image

If you prefer to include your models and custom nodes directly in the Docker image, follow these steps:

1. **Fork the Repository**:
   - Fork this repository to your own GitHub account.

#### Adding Custom Models

To include additional models in your Docker image, edit the `Dockerfile` and add the download commands:

```Dockerfile
RUN if [ "$MODEL_TYPE" = "custom" ]; then \
    fetch_model_2 "https://huggingface.co/your-model/resolve/main/model.safetensors" "checkpoints/model.safetensors" "$HUGGINGFACE_ACCESS_TOKEN"; \
fi
```

#### Adding Custom Nodes

To include custom nodes in your Docker image:

1. [Export a snapshot from ComfyUI Manager](https://github.com/ltdrdata/ComfyUI-Manager?tab=readme-ov-file#snapshot-manager) that includes all your desired custom nodes

   1. Open "Manager > Snapshot Manager"
   2. Create a new snapshot by clicking on "Save snapshot"
   3. Get the `*_snapshot.json` from your ComfyUI: `ComfyUI/custom_nodes/ComfyUI-Manager/snapshots`

2. Save the snapshot file in the root directory of the project
3. The snapshot will be automatically restored during the Docker build process, see [Building the Image](#building-the-image)

> [!NOTE]
>
> - Some custom nodes may download additional models during installation, which can significantly increase the image size
> - Having many custom nodes may increase ComfyUI's initialization time

#### Building the Image

Use the provided build scripts to create your customized Docker images:

**Using rebuildall.sh (builds all model types):**
```bash
bash rebuildall.sh
```

**Using rebuildall_screen.sh (builds in screen session with logging):**
```bash
bash rebuildall_screen.sh
```

**Manual build for specific model type:**
```bash
# Build the base image
docker build -t <your_dockerhub_username>/runpod-worker-comfy:dev-base --target base --platform linux/amd64 .

# Build the SDXL image
docker build --build-arg MODEL_TYPE=sdxl -t <your_dockerhub_username>/runpod-worker-comfy:dev-sdxl --platform linux/amd64 .

# Build the SD3.5 image
docker build --build-arg MODEL_TYPE=sd35 --build-arg HUGGINGFACE_ACCESS_TOKEN=<your-huggingface-token> -t <your_dockerhub_username>/runpod-worker-comfy:dev-sd35 --platform linux/amd64 .
```

> [!NOTE]  
> Ensure to specify `--platform linux/amd64` to avoid errors on RunPod, see [issue #13](https://github.com/blib-la/runpod-worker-comfy/issues/13)

## Local testing

Both tests will use the data from [test_input.json](./test_input.json), so make your changes in there to test this properly.

### Setup

1. Make sure you have Python >= 3.10
2. Create a virtual environment:
   ```bash
   python -m venv venv
   ```
3. Activate the virtual environment:
   - **Windows**:
     ```bash
     .\venv\Scripts\activate
     ```
   - **Mac / Linux**:
     ```bash
     source ./venv/bin/activate
     ```
4. Install the dependencies:
   ```bash
   pip install -r requirements.txt
   pip install websockets  # For WebSocket functionality
   ```

#### Setup for Windows

1. Install WSL2 and a Linux distro (like Ubuntu) following [this guide](https://ubuntu.com/tutorials/install-ubuntu-on-wsl2-on-windows-11-with-gui-support#1-overview). You can skip the "Install and use a GUI package" part.
2. After installing Ubuntu, open the terminal and log in:
   ```bash
   wsl -d Ubuntu
   ```
3. Update the packages:
   ```bash
   sudo apt update
   ```
4. Install Docker in Ubuntu:
   - Follow the [official Docker installation guide](https://docs.docker.com/engine/install/ubuntu/).
   - Install docker-compose:
     ```bash
     sudo apt-get install docker-compose
     ```
   - Install the NVIDIA Toolkit in Ubuntu:
     Follow [this guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuring-docker) and create the `nvidia` runtime.
5. Enable GPU acceleration on Ubuntu on WSL2:
   Follow [this guide](https://canonical-ubuntu-wsl.readthedocs-hosted.com/en/latest/tutorials/gpu-cuda/).
   - If you already have your GPU driver installed on Windows, you can skip the "Install the appropriate Windows vGPU driver for WSL" step.
6. Add your user to the `docker` group to use Docker without `sudo`:
   ```bash
   sudo usermod -aG docker $USER
   ```

Once these steps are completed, you can either run the Docker image directly on Windows using Docker Desktop or switch to Ubuntu in the terminal to run the Docker image via WSL

```bash
wsl -d Ubuntu
```

> [!NOTE]
>
> - Windows: Accessing the API or ComfyUI might not work when you run the Docker Image via WSL, so it is recommended to run the Docker Image directly on Windows using Docker Desktop

### Testing the RunPod handler

- Run all tests: `python -m unittest discover`
- If you want to run a specific test: `python -m unittest tests.test_rp_handler.TestRunpodWorkerComfy.test_bucket_endpoint_not_configured`

You can also start the handler itself to have the local server running: `python src/rp_handler.py`
To get this to work you will also need to start "ComfyUI", otherwise the handler will not work.

### Local API

For enhanced local development, you can start an API server that simulates the RunPod worker environment. This feature is particularly useful for debugging and testing your integrations locally.

Set the `SERVE_API_LOCALLY` environment variable to `true` to activate the local API server when running your Docker container. This is already the default value in the `docker-compose.yml`, so you can get it running by executing:

```bash
docker-compose up
```

> [!NOTE]
>
> - This will only work on computer with an NVIDIA GPU for now, as it requires CUDA. Please open an issue if you want to use it on a CPU / Mac

#### Access the local Worker API

- With the local API server running, it's accessible at: [localhost:8000](http://localhost:8000)
- When you open this in your browser, you can also see the API documentation and can interact with the API directly

> [!NOTE]
>
> - Windows: Accessing the API or ComfyUI might not work when you run the Docker Image via WSL, so it is recommended to run the Docker Image directly on Windows using Docker Desktop

#### Access local ComfyUI

- With the local API server running, you can access ComfyUI at: [localhost:8188](http://localhost:8188)

> [!NOTE]
>
> - Windows: Accessing the API or ComfyUI might not work when you run the Docker Image via WSL, so it is recommended to run the Docker Image directly on Windows using Docker Desktop

## Development and Build Scripts

### rebuildall.sh

The main build script that creates Docker images for all supported model types:

- **Base**: Clean ComfyUI without pre-loaded models
- **SDXL**: Stable Diffusion XL with optimized VAE
- **SD3.5**: Stable Diffusion 3.5 Large with text encoders
- **FLUX.1**: FLUX.1 Dev models
- **FLUX.1 Kontext**: FLUX.1 Kontext variant
- **Wan 2.1**: Video generation models

The script automatically:
- Activates the virtual environment
- Starts the model server for caching
- Builds each image variant
- Pushes to Docker Hub
- Stops the model server

### rebuildall_screen.sh

Enhanced build script that runs the build process in a screen session with logging:

- Creates timestamped log files in the `logs/` directory
- Runs the build process in a detached screen session
- Provides commands to monitor progress and attach to the session
- Useful for long-running builds that you want to monitor remotely

**Usage:**
```bash
bash rebuildall_screen.sh
```

**Monitor progress:**
```bash
# View the log file
tail -f logs/rebuild_YYYYMMDD_HHMMSS.log

# Attach to the screen session
screen -r rebuild_session

# Detach from session (while attached)
Ctrl+A, then D
```

## Automatically deploy to Docker hub with GitHub Actions

The repo contains two workflows that publish the image to Docker hub using GitHub Actions:

- [dev.yml](.github/workflows/dev.yml): Creates the image and pushes it to Docker hub with the `dev` tag on every push to the `main` branch
- [release.yml](.github/workflows/release.yml): Creates the image and pushes it to Docker hub with the `latest` and the release tag. It will only be triggered when you create a release on GitHub

If you want to use this, you should add these **secrets** to your repository:

| Configuration Variable     | Description                               | Example Value       |
| -------------------------- | ----------------------------------------- | ------------------- |
| `DOCKERHUB_USERNAME`       | Your Docker Hub username.                 | `your-username`     |
| `DOCKERHUB_TOKEN`          | Your Docker Hub token for authentication. | `your-token`        |
| `HUGGINGFACE_ACCESS_TOKEN` | Your READ access token from Hugging Face  | `your-access-token` |

And also make sure to add these **variables** to your repository:

| Variable Name    | Description                                                  | Example Value         |
| ---------------- | ------------------------------------------------------------ | --------------------- |
| `DOCKERHUB_REPO` | The repository on Docker Hub where the image will be pushed. | `gjbm2`               |
| `DOCKERHUB_IMG`  | The name of the image to be pushed to Docker Hub.            | `runpod-worker-comfy` |

## Acknowledgments

- Thanks to [all contributors](https://github.com/blib-la/runpod-worker-comfy/graphs/contributors) for your awesome work
- Thanks to [Justin Merrell](https://github.com/justinmerrell) from RunPod for [worker-1111](https://github.com/runpod-workers/worker-a1111), which was used to get inspired on how to create this worker
- Thanks to [Ashley Kleynhans](https://github.com/ashleykleynhans) for [runpod-worker-a1111](https://github.com/ashleykleynhans/runpod-worker-a1111), which was used to get inspired on how to create this worker
- Thanks to [comfyanonymous](https://github.com/comfyanonymous) for creating [ComfyUI](https://github.com/comfyanonymous/ComfyUI), which provides such an awesome API to interact with Stable Diffusion and beyond
