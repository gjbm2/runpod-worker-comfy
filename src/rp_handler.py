# Running rp_handler.py v 21.32 9-Apr-25

import runpod
from runpod.serverless.utils import rp_upload
import json
import urllib.request
import urllib.parse
import time
import os
import glob
import requests
import base64
from io import BytesIO
import uuid
import asyncio
import websockets  # ✅ added for WebSocket logging

# Time to wait between API check attempts in milliseconds
COMFY_API_AVAILABLE_INTERVAL_MS = 100
# Maximum number of API check attempts
COMFY_API_AVAILABLE_MAX_RETRIES = 100000
# Time to wait between poll attempts in milliseconds
COMFY_POLLING_INTERVAL_MS = int(os.environ.get("COMFY_POLLING_INTERVAL_MS", 1000))
# Maximum number of poll attempts
COMFY_POLLING_MAX_RETRIES = int(os.environ.get("COMFY_POLLING_MAX_RETRIES", 100000))
# Host where ComfyUI is running
COMFY_HOST = "127.0.0.1:8188"
# Enforce a clean state after each job is done
# see https://docs.runpod.io/docs/handler-additional-controls#refresh-worker
REFRESH_WORKER = os.environ.get("REFRESH_WORKER", "false").lower() == "true"

# --- WebSocket listener for ComfyUI progress (DEBUGGING only) ---
async def listen_to_ws(stop_event, job_id, detailed_logging=True):
    comfy_uri = f"ws://{COMFY_HOST}/ws"
    relay_uri = os.environ.get("BACKEND_WS_URL", "ws://185.254.136.253:8765/")

    try:
        async with websockets.connect(comfy_uri) as comfy_ws, \
                   websockets.connect(relay_uri) as relay_ws:

            print("📡 Connected to ComfyUI WS and relay WS.")

            while not stop_event.is_set():
                try:
                    msg = await asyncio.wait_for(comfy_ws.recv(), timeout=1)
                    parsed_msg = json.loads(msg)

                    if detailed_logging:
                        print("🧠 WS:", json.dumps(parsed_msg, indent=2))

                    # Wrap with job_id before relaying
                    wrapped = json.dumps({
                        "job_id": job_id,
                        "comfy": parsed_msg
                    })

                    await relay_ws.send(wrapped)
                    if detailed_logging:
                        print(f"📤 Relayed to backend WS with job_id: {job_id}")

                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    print(f"⚠️ Error in WS relay loop: {e}")
                    break

    except Exception as e:
        print(f"❌ WebSocket connection error: {e}")


def validate_input(job_input):
    """
    Validates the input for the handler function.

    Args:
        job_input (dict): The input data to validate.

    Returns:
        tuple: A tuple containing the validated data and an error message, if any.
               The structure is (validated_data, error_message).
    """
    # Validate if job_input is provided
    if job_input is None:
        return None, "Please provide input"

    # Check if input is a string and try to parse it as JSON
    if isinstance(job_input, str):
        try:
            job_input = json.loads(job_input)
        except json.JSONDecodeError:
            return None, "Invalid JSON format in input"

    # Validate 'workflow' in input
    workflow = job_input.get("workflow")
    if workflow is None:
        return None, "Missing 'workflow' parameter"

    # Validate 'images' in input, if provided
    images = job_input.get("images")
    if images is not None:
        if not isinstance(images, list) or not all(
            "name" in image and "image" in image for image in images
        ):
            return (
                None,
                "'images' must be a list of objects with 'name' and 'image' keys",
            )

    # Return validated data and no error
    return {"workflow": workflow, "images": images}, None


def check_server(url, retries=5000, delay=50):
    """
    Check if a server is reachable via HTTP GET request

    Args:
    - url (str): The URL to check
    - retries (int, optional): The number of times to attempt connecting to the server. Default is 50
    - delay (int, optional): The time in milliseconds to wait between retries. Default is 500

    Returns:
    bool: True if the server is reachable within the given number of retries, otherwise False
    """

    for i in range(retries):
        try:
            response = requests.get(url)

            # If the response status code is 200, the server is up and running
            if response.status_code == 200:
                print(f"runpod-worker-comfy - API is reachable")
                return True
        except requests.RequestException as e:
            # If an exception occurs, the server may not be ready
            pass

        # Wait for the specified delay before retrying
        time.sleep(delay / 1000)

    print(
        f"runpod-worker-comfy - Failed to connect to server at {url} after {retries} attempts."
    )
    return False

def upload_images(images):
    """
    Upload a list of base64 encoded images to the ComfyUI server using the /upload/image endpoint.

    Args:
        images (list): A list of dictionaries, each containing the 'name' of the image and the 'image' as a base64 encoded string.
        server_address (str): The address of the ComfyUI server.

    Returns:
        list: A list of responses from the server for each image upload.
    """
    if not images:
        return {"status": "success", "message": "No images to upload", "details": []}

    responses = []
    upload_errors = []

    print(f"runpod-worker-comfy - image(s) upload")

    for image in images:
        name = image["name"]
        image_data = image["image"]
        blob = base64.b64decode(image_data)

        # Prepare the form data
        files = {
            "image": (name, BytesIO(blob), "image/png"),
            "overwrite": (None, "true"),
        }

        # POST request to upload the image
        response = requests.post(f"http://{COMFY_HOST}/upload/image", files=files)
        if response.status_code != 200:
            upload_errors.append(f"Error uploading {name}: {response.text}")
        else:
            responses.append(f"Successfully uploaded {name}")

    if upload_errors:
        print(f"runpod-worker-comfy - image(s) upload with errors")
        return {
            "status": "error",
            "message": "Some images failed to upload",
            "details": upload_errors,
        }

    print(f"runpod-worker-comfy - image(s) upload complete")
    return {
        "status": "success",
        "message": "All images uploaded successfully",
        "details": responses,
    }


def queue_workflow(workflow):
    """
    Queue a workflow to be processed by ComfyUI

    Args:
        workflow (dict): A dictionary containing the workflow to be processed

    Returns:
        dict: The JSON response from ComfyUI after processing the workflow
    """

    # The top level element "prompt" is required by ComfyUI
    data = json.dumps({"prompt": workflow}).encode("utf-8")

    req = urllib.request.Request(f"http://{COMFY_HOST}/prompt", data=data)
    return json.loads(urllib.request.urlopen(req).read())


def get_history(prompt_id):
    """
    Retrieve the history of a given prompt using its ID

    Args:
        prompt_id (str): The ID of the prompt whose history is to be retrieved

    Returns:
        dict: The history of the prompt, containing all the processing steps and results
    """
    with urllib.request.urlopen(f"http://{COMFY_HOST}/history/{prompt_id}") as response:
        return json.loads(response.read())


def base64_encode(img_path):
    """
    Returns base64 encoded image.

    Args:
        img_path (str): The path to the image

    Returns:
        str: The base64 encoded image
    """
    with open(img_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
        return f"{encoded_string}"


def process_output_images(outputs, job_id):
    """
    This function takes the "outputs" from image generation and the job ID,
    then determines the correct way to return the image, either as a direct URL
    to an AWS S3 bucket or as a base64 encoded string, depending on the
    environment configuration.

    Args:
        outputs (dict): A dictionary containing the outputs from image generation,
                        typically includes node IDs and their respective output data.
        job_id (str): The unique identifier for the job.

    Returns:
        dict: A dictionary with the status ('success' or 'error') and the message,
              which is either the URL to the image in the AWS S3 bucket or a base64
              encoded string of the image. In case of error, the message details the issue.

    The function works as follows:
    - It first determines the output path for the images from an environment variable,
      defaulting to "/comfyui/output" if not set.
    - It then iterates through the outputs to find the filenames of the generated images.
    - After confirming the existence of the image in the output folder, it checks if the
      AWS S3 bucket is configured via the BUCKET_ENDPOINT_URL environment variable.
    - If AWS S3 is configured, it uploads the image to the bucket and returns the URL.
    - If AWS S3 is not configured, it encodes the image in base64 and returns the string.
    - If the image file does not exist in the output folder, it returns an error status
      with a message indicating the missing image file.
    """

    # The path where ComfyUI stores the generated images
    COMFY_OUTPUT_PATH = os.environ.get("COMFY_OUTPUT_PATH", "/comfyui/output")

    output_images = {}

    for node_id, node_output in outputs.items():
        if "images" in node_output:
            for image in node_output["images"]:
                output_images = os.path.join(image["subfolder"], image["filename"])

    print(f"runpod-worker-comfy - image generation is done")

    # expected image output folder
    local_image_path = f"{COMFY_OUTPUT_PATH}/{output_images}"

    print(f"runpod-worker-comfy - {local_image_path}")

    # The image is in the output folder
    if os.path.exists(local_image_path):
        if os.environ.get("BUCKET_ENDPOINT_URL", False):
            # URL to image in AWS S3
            image = rp_upload.upload_image(job_id, local_image_path)
            print(
                "runpod-worker-comfy - the image was generated and uploaded to AWS S3"
            )
        else:
            # base64 image
            image = base64_encode(local_image_path)
            print(
                "runpod-worker-comfy - the image was generated and converted to base64"
            )
            
        if os.environ.get("DETAILED_COMFY_LOGGING", "true").lower() == "true":
            print(f"Published image/video URL: {image}")
        return {
            "status": "success",
            "message": image,
        }
    else:
        # If no image was found, try looking for a fallback video file
        if os.environ.get("BUCKET_ENDPOINT_URL", False):
            for ext, mime in [
                ("mp4", "video/mp4"),       # ✅ Add H.264 MP4 support
                ("webm", "video/webm"),
                ("webp", "image/webp")
            ]:
                pattern = os.path.join(COMFY_OUTPUT_PATH, f"output_video*.{ext}")
                matching_files = glob.glob(pattern)
                if matching_files:
                    # ✅ Pick the most recently modified file
                    latest_video = max(matching_files, key=os.path.getmtime)
                    try:
                        random_name = str(uuid.uuid4())[:8]
                        filename = f"{random_name}.{ext}"
                        video_url = rp_upload.upload_file_to_bucket(
                            file_name=filename,
                            file_location=latest_video,
                            prefix=job_id,
                            extra_args={"ContentType": mime}
                        )
                        print(f"runpod-worker-comfy - video was generated and uploaded to AWS S3 ({video_url})")
                        return {
                            "status": "success",
                            "message": video_url
                        }
                    except Exception as e:
                        print(f"runpod-worker-comfy - failed to upload fallback video {latest_video}: {e}")
        else:
            print("runpod-worker-comfy - S3 not configured, skipping video upload fallback.")

        # Neither image nor video found
        print("runpod-worker-comfy - an image does not exist in the output folder, or a video does not exist, or video & no S3 access")
        return {
            "status": "error",
            "message": f"the image does not exist in the specified output folder: {local_image_path}",
        }

async def handler(job):
    DETAILED_LOGGING = os.environ.get("DETAILED_COMFY_LOGGING", "true").lower() == "true"
    DETAILED_LOGGING = True
    if DETAILED_LOGGING:
        print("runpod-worker-comfy - Detailed logging enabled.")

    job_input = job["input"]
    # ✅ Handle restart trigger
    if isinstance(job_input, dict) and job_input.get("type") == "restart":
        print("🔁 Soft reboot requested via job input. Restarting worker process...")
        os.execv(sys.executable, ['python'] + sys.argv)  # Replaces current process
    
    validated_data, error_message = validate_input(job_input)
    if error_message:
        print(f"❌ Validation error: {error_message}")
        return {"error": error_message}
    
    workflow = validated_data["workflow"]
    images = validated_data.get("images")

    if DETAILED_LOGGING:
        print(f"runpod-worker-comfy - Workflow input: {json.dumps(workflow)[:500]}...")

    if not check_server(f"http://{COMFY_HOST}", COMFY_API_AVAILABLE_MAX_RETRIES, COMFY_API_AVAILABLE_INTERVAL_MS):
        print("❌ ComfyUI API is not reachable.")
        return {"error": "ComfyUI API is not reachable"}

    upload_result = upload_images(images)
    if upload_result["status"] == "error":
        print(f"❌ Image upload failed: {upload_result}")
        return upload_result

    try:
        queued_workflow = queue_workflow(workflow)
        prompt_id = queued_workflow["prompt_id"]
        print(f"runpod-worker-comfy - queued workflow with ID {prompt_id}")
    except Exception as e:
        print(f"❌ Exception while queuing workflow: {e}")
        return {"error": f"Error queuing workflow: {str(e)}"}

    # ✅ Start WebSocket listener if logging enabled and loop available
    ws_task = None
    ws_stop_event = None
    try:
        loop = asyncio.get_running_loop()
        ws_stop_event = asyncio.Event()
        ws_task = loop.create_task(
            listen_to_ws(ws_stop_event, job_id=job["id"], detailed_logging=True)
        )
        print("🚀 WebSocket listener task started.")
    except RuntimeError:
        print("❌ No running event loop. Skipping WebSocket listener.")

    print(f"runpod-worker-comfy - wait until image generation is complete")
    retries = 0
    history = {}
    try:
        while retries < COMFY_POLLING_MAX_RETRIES:
            try:
                history = get_history(prompt_id)
                if prompt_id in history:
                    prompt_data = history[prompt_id]
                    if "outputs" in prompt_data and prompt_data["outputs"]:
                        print("runpod-worker-comfy - ✅ Outputs detected, generation complete.")
                        break
            except Exception as e:
                print(f"runpod-worker-comfy - ⚠️ History fetch error: {e}")
            await asyncio.sleep(COMFY_POLLING_INTERVAL_MS / 1000)
            retries += 1
        else:
            print("❌ Max retries reached while waiting for image generation.")
            return {"error": "Max retries reached while waiting for image generation"}
    except Exception as e:
        print(f"❌ Exception while polling for history: {e}")
        return {"error": f"Error waiting for image generation: {str(e)}"}

    try:
        outputs = history[prompt_id].get("outputs", {})
        if not outputs:
            print("❌ No outputs in history object.")
            return {"error": "No outputs found for prompt"}

        images_result = process_output_images(outputs, job["id"])
        if images_result.get("status") != "success":
            print(f"❌ process_output_images failed: {images_result}")
            return images_result

        result = {**images_result, "refresh_worker": REFRESH_WORKER}

        # ✅ Cleanly shut down WebSocket listener
        if ws_task:
            print("🛑 Stopping WebSocket listener...")
            ws_stop_event.set()
            await ws_task
            print("✅ WebSocket listener stopped.")

        print("runpod-worker-comfy - handler completed.")
        return result

    except Exception as e:
        print(f"❌ Unexpected exception during final processing: {e}")
        return {"error": f"Unhandled error while finalizing result: {str(e)}"}


# ✅ Async wrapper for handler
async def async_handler(job):
    return await handler(job)

# ✅ Register handler with RunPod
if __name__ == "__main__":
    runpod.serverless.start({"handler": async_handler})
