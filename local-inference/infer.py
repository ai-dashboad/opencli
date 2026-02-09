#!/usr/bin/env python3
"""
OpenCLI Local Inference Engine

Runs local AI models for image/video generation via subprocess.
Communication: JSON on stdin → JSON on stdout.

Usage:
  echo '{"action":"generate_image","model":"waifu_diffusion","prompt":"..."}' | python infer.py
  python infer.py --check-env
  python infer.py --list-models
  python infer.py --model-status <model_id>
  python infer.py --download <model_id>
"""

import argparse
import base64
import json
import os
import sys
import time
from io import BytesIO
from pathlib import Path

# Model registry
MODELS = {
    "waifu_diffusion": {
        "name": "Waifu Diffusion",
        "repo": "hakurei/waifu-diffusion",
        "type": "text2img",
        "pipeline": "StableDiffusionPipeline",
        "default_size": 512,
        "capabilities": ["image"],
        "size_gb": 2.0,
        "description": "Anime-style image generation based on Stable Diffusion 1.5",
        "tags": ["anime", "illustration"],
    },
    "animagine_xl": {
        "name": "Animagine XL 3.1",
        "repo": "cagliostrolab/animagine-xl-3.1",
        "type": "text2img",
        "pipeline": "StableDiffusionXLPipeline",
        "default_size": 1024,
        "capabilities": ["image"],
        "size_gb": 6.5,
        "description": "High-quality anime image generation based on SDXL",
        "tags": ["anime", "illustration", "xl"],
    },
    "pony_diffusion": {
        "name": "Pony Diffusion V6 XL",
        "repo": "AstraliteHeart/pony-diffusion-v6-xl",
        "type": "text2img",
        "pipeline": "StableDiffusionXLPipeline",
        "default_size": 1024,
        "capabilities": ["image"],
        "size_gb": 6.5,
        "description": "Versatile anime/illustration model based on SDXL",
        "tags": ["anime", "illustration", "versatile", "xl"],
    },
    "animatediff": {
        "name": "AnimateDiff",
        "repo": "guoyww/animatediff-motion-adapter-v1-5-3",
        "base_repo": "runwayml/stable-diffusion-v1-5",
        "type": "text2video",
        "pipeline": "AnimateDiffPipeline",
        "capabilities": ["video", "animation"],
        "size_gb": 4.5,
        "description": "Generate short animated videos from text prompts",
        "tags": ["animation", "video", "motion"],
    },
    "stable_video_diffusion": {
        "name": "Stable Video Diffusion",
        "repo": "stabilityai/stable-video-diffusion-img2vid-xt",
        "type": "img2video",
        "pipeline": "StableVideoDiffusionPipeline",
        "capabilities": ["video"],
        "size_gb": 4.0,
        "description": "Generate video from a single image (image-to-video)",
        "tags": ["video", "img2vid"],
    },
    "animegan_v3": {
        "name": "AnimeGAN v3",
        "repo": "bryandlee/animegan2-pytorch",
        "type": "style_transfer",
        "pipeline": "custom",
        "capabilities": ["image", "style_transfer"],
        "size_gb": 0.1,
        "description": "Transform photos into anime-style artwork",
        "tags": ["anime", "style_transfer", "lightweight"],
    },
    "ip_adapter_face": {
        "name": "IP-Adapter FaceID",
        "repo": "h94/IP-Adapter-FaceID",
        "type": "ip_adapter",
        "pipeline": "custom",
        "capabilities": ["image", "character_consistency"],
        "size_gb": 1.5,
        "description": "Maintain character face consistency across generated images",
        "tags": ["face", "consistency", "ip-adapter"],
    },
    "animatediff_v3": {
        "name": "AnimateDiff V3",
        "repo": "guoyww/animatediff-motion-adapter-v3",
        "base_repo": "runwayml/stable-diffusion-v1-5",
        "type": "text2video",
        "pipeline": "AnimateDiffPipeline",
        "capabilities": ["video", "animation", "camera_control"],
        "size_gb": 4.8,
        "description": "AnimateDiff V3 with MotionLoRA camera control for cinematic video",
        "tags": ["animation", "video", "motion", "camera", "lora"],
    },
    "realesrgan": {
        "name": "Real-ESRGAN Anime",
        "repo": "ai-forever/Real-ESRGAN",
        "type": "upscale",
        "pipeline": "custom",
        "capabilities": ["upscale"],
        "size_gb": 0.07,
        "description": "4x anime-optimized upscaling via Real-ESRGAN",
        "tags": ["upscale", "super_resolution", "anime"],
    },
    "controlnet_lineart_anime": {
        "name": "ControlNet Lineart Anime",
        "repo": "lllyasviel/control_v11p_sd15_lineart_anime",
        "type": "controlnet",
        "pipeline": "custom",
        "capabilities": ["controlnet", "lineart"],
        "size_gb": 1.4,
        "description": "ControlNet for anime lineart-guided generation (SD1.5)",
        "tags": ["controlnet", "lineart", "anime", "consistency"],
    },
    "controlnet_openpose": {
        "name": "ControlNet OpenPose",
        "repo": "lllyasviel/control_v11p_sd15_openpose",
        "type": "controlnet",
        "pipeline": "custom",
        "capabilities": ["controlnet", "pose"],
        "size_gb": 1.4,
        "description": "ControlNet for pose-guided generation (SD1.5)",
        "tags": ["controlnet", "pose", "skeleton", "consistency"],
    },
    "controlnet_depth": {
        "name": "ControlNet Depth",
        "repo": "lllyasviel/control_v11f1p_sd15_depth",
        "type": "controlnet",
        "pipeline": "custom",
        "capabilities": ["controlnet", "depth"],
        "size_gb": 1.4,
        "description": "ControlNet for depth-guided generation (SD1.5)",
        "tags": ["controlnet", "depth", "3d", "consistency"],
    },
}

MODELS_DIR = Path.home() / ".opencli" / "models"


def get_device():
    """Detect best available device."""
    import torch

    if torch.cuda.is_available():
        return "cuda"
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def check_environment():
    """Check if all dependencies are installed."""
    result = {"python_version": sys.version, "ok": True, "missing": [], "device": "cpu"}

    try:
        import torch

        result["torch_version"] = torch.__version__
        result["device"] = get_device()
        if result["device"] == "cuda":
            result["gpu"] = torch.cuda.get_device_name(0)
        elif result["device"] == "mps":
            result["gpu"] = "Apple Silicon (MPS)"
        else:
            result["gpu"] = None
    except ImportError:
        result["ok"] = False
        result["missing"].append("torch")

    for pkg in ["diffusers", "transformers", "accelerate", "safetensors", "PIL"]:
        try:
            __import__(pkg)
        except ImportError:
            result["ok"] = False
            result["missing"].append(pkg)

    # Check optional upscale/interpolation deps
    optional = {}
    try:
        import realesrgan
        optional["realesrgan"] = True
    except ImportError:
        optional["realesrgan"] = False
    import shutil
    optional["rife"] = shutil.which("rife-ncnn-vulkan") is not None
    result["optional"] = optional

    result["models_dir"] = str(MODELS_DIR)
    result["models_dir_exists"] = MODELS_DIR.exists()
    return result


def get_model_status(model_id):
    """Check if a model is downloaded and its disk size."""
    if model_id not in MODELS:
        return {"error": f"Unknown model: {model_id}"}

    info = MODELS[model_id]
    model_dir = MODELS_DIR / model_id

    status = {
        "id": model_id,
        "name": info["name"],
        "type": info["type"],
        "capabilities": info["capabilities"],
        "size_gb": info["size_gb"],
        "description": info["description"],
        "tags": info.get("tags", []),
        "downloaded": False,
        "disk_size_mb": 0,
    }

    if model_dir.exists():
        # Check for model files
        total_size = sum(f.stat().st_size for f in model_dir.rglob("*") if f.is_file())
        status["downloaded"] = total_size > 1_000_000  # At least 1MB of files
        status["disk_size_mb"] = round(total_size / (1024 * 1024), 1)

    return status


def list_models():
    """List all models with download status."""
    return [get_model_status(mid) for mid in MODELS]


def download_model(model_id):
    """Download a model from HuggingFace Hub."""
    if model_id not in MODELS:
        return {"error": f"Unknown model: {model_id}"}

    info = MODELS[model_id]
    model_dir = MODELS_DIR / model_id
    model_dir.mkdir(parents=True, exist_ok=True)

    try:
        from huggingface_hub import snapshot_download

        # Special handling for AnimeGAN (custom repo)
        if model_id == "animegan_v3":
            return _download_animegan(model_dir)

        # For AnimateDiff (v1 or v3), download both motion adapter and base model
        if model_id in ("animatediff", "animatediff_v3"):
            print(json.dumps({"progress": 0.1, "message": "Downloading base model..."}), flush=True)
            snapshot_download(
                info["base_repo"],
                local_dir=str(MODELS_DIR / "sd15_base"),
                ignore_patterns=["*.ckpt", "*.bin"],
            )
            print(json.dumps({"progress": 0.6, "message": "Downloading motion adapter..."}), flush=True)

        print(json.dumps({"progress": 0.2, "message": f"Downloading {info['name']}..."}), flush=True)

        snapshot_download(
            info["repo"],
            local_dir=str(model_dir),
            ignore_patterns=["*.ckpt", "*.bin"] if "xl" in model_id else ["*.ckpt"],
        )

        print(json.dumps({"progress": 1.0, "message": "Download complete"}), flush=True)
        return {"success": True, "model_id": model_id, "path": str(model_dir)}
    except Exception as e:
        return {"error": f"Download failed: {str(e)}"}


def _download_animegan(model_dir):
    """Download AnimeGAN v3 model weights."""
    try:
        from huggingface_hub import hf_hub_download

        for fname in ["face_paint_512_v2.pt", "paprika.pt", "celeba_distill.pt"]:
            print(json.dumps({"progress": 0.3, "message": f"Downloading {fname}..."}), flush=True)
            try:
                hf_hub_download(
                    "bryandlee/animegan2-pytorch",
                    filename=fname,
                    local_dir=str(model_dir),
                )
            except Exception:
                pass  # Some weights may not exist in this repo

        print(json.dumps({"progress": 1.0, "message": "Download complete"}), flush=True)
        return {"success": True, "model_id": "animegan_v3", "path": str(model_dir)}
    except Exception as e:
        return {"error": f"Download failed: {str(e)}"}


def generate_image(params):
    """Generate an image using a local text-to-image model."""
    import torch
    from PIL import Image

    model_id = params.get("model", "waifu_diffusion")
    if model_id not in MODELS:
        return {"error": f"Unknown model: {model_id}"}

    info = MODELS[model_id]
    if info["type"] != "text2img":
        return {"error": f"Model {model_id} does not support text-to-image"}

    model_dir = MODELS_DIR / model_id
    if not model_dir.exists():
        return {"error": f"Model not downloaded. Run: python infer.py --download {model_id}"}

    prompt = params.get("prompt", "")
    negative_prompt = params.get("negative_prompt", "low quality, blurry, bad anatomy")
    width = params.get("width", info.get("default_size", 512))
    height = params.get("height", info.get("default_size", 512))
    steps = params.get("steps", 30)
    guidance_scale = params.get("guidance_scale", 7.5)
    seed = params.get("seed")

    device = get_device()
    dtype = torch.float16 if device == "cuda" else torch.float32

    try:
        # Load pipeline
        if info["pipeline"] == "StableDiffusionXLPipeline":
            from diffusers import StableDiffusionXLPipeline

            pipe = StableDiffusionXLPipeline.from_pretrained(
                str(model_dir), torch_dtype=dtype, use_safetensors=True
            )
        else:
            from diffusers import StableDiffusionPipeline

            pipe = StableDiffusionPipeline.from_pretrained(
                str(model_dir), torch_dtype=dtype, use_safetensors=True
            )

        pipe = pipe.to(device)

        # Enable memory optimizations
        if device == "cuda":
            pipe.enable_model_cpu_offload()
        elif device == "mps":
            pass  # MPS doesn't support cpu offload well

        generator = None
        if seed is not None:
            generator = torch.Generator(device=device).manual_seed(seed)

        # Generate
        result = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            width=width,
            height=height,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
            generator=generator,
        )

        image = result.images[0]

        # Convert to base64
        buf = BytesIO()
        image.save(buf, format="PNG")
        img_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {
            "success": True,
            "image_base64": img_base64,
            "model": model_id,
            "width": width,
            "height": height,
            "steps": steps,
        }
    except Exception as e:
        return {"error": f"Generation failed: {str(e)}"}
    finally:
        # Free memory
        try:
            del pipe
            if device == "cuda":
                torch.cuda.empty_cache()
        except Exception:
            pass


def generate_video_animatediff(params):
    """Generate a short video using AnimateDiff."""
    import torch

    model_dir = MODELS_DIR / "animatediff"
    base_dir = MODELS_DIR / "sd15_base"

    if not model_dir.exists():
        return {"error": "AnimateDiff not downloaded. Run: python infer.py --download animatediff"}

    prompt = params.get("prompt", "")
    negative_prompt = params.get("negative_prompt", "low quality, blurry")
    num_frames = params.get("frames", 16)
    steps = params.get("steps", 25)
    guidance_scale = params.get("guidance_scale", 7.5)

    device = get_device()
    dtype = torch.float16 if device == "cuda" else torch.float32

    try:
        from diffusers import AnimateDiffPipeline, MotionAdapter, DDIMScheduler

        adapter = MotionAdapter.from_pretrained(str(model_dir), torch_dtype=dtype)

        pipe = AnimateDiffPipeline.from_pretrained(
            str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
            motion_adapter=adapter,
            torch_dtype=dtype,
        )
        pipe.scheduler = DDIMScheduler.from_pretrained(
            str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
            subfolder="scheduler",
            clip_sample=False,
            timestep_spacing="linspace",
            beta_schedule="linear",
            steps_offset=1,
        )
        pipe = pipe.to(device)

        if device == "cuda":
            pipe.enable_model_cpu_offload()

        result = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_frames=num_frames,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
        )

        frames = result.frames[0]  # List of PIL Images

        # Save as MP4 using PIL/imageio or ffmpeg
        output_path = MODELS_DIR / "output" / f"animatediff_{int(time.time())}.mp4"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            from diffusers.utils import export_to_video

            export_to_video(frames, str(output_path), fps=8)
        except ImportError:
            # Fallback: save frames and use ffmpeg
            return _frames_to_video(frames, str(output_path))

        with open(output_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "video_base64": video_base64,
            "model": "animatediff",
            "frames": num_frames,
            "video_path": str(output_path),
        }
    except Exception as e:
        return {"error": f"Video generation failed: {str(e)}"}
    finally:
        try:
            del pipe, adapter
            if device == "cuda":
                torch.cuda.empty_cache()
        except Exception:
            pass


def generate_video_svd(params):
    """Generate video from image using Stable Video Diffusion."""
    import torch
    from PIL import Image

    model_dir = MODELS_DIR / "stable_video_diffusion"
    if not model_dir.exists():
        return {"error": "SVD not downloaded. Run: python infer.py --download stable_video_diffusion"}

    image_base64 = params.get("image_base64")
    if not image_base64:
        return {"error": "image_base64 is required for SVD"}

    num_frames = params.get("frames", 25)
    decode_chunk_size = params.get("decode_chunk_size", 8)

    device = get_device()
    dtype = torch.float16 if device == "cuda" else torch.float32

    try:
        from diffusers import StableVideoDiffusionPipeline
        from diffusers.utils import export_to_video

        pipe = StableVideoDiffusionPipeline.from_pretrained(
            str(model_dir), torch_dtype=dtype, variant="fp16" if device == "cuda" else None
        )
        pipe = pipe.to(device)

        if device == "cuda":
            pipe.enable_model_cpu_offload()

        # Decode input image
        img_bytes = base64.b64decode(image_base64)
        image = Image.open(BytesIO(img_bytes)).convert("RGB")
        image = image.resize((1024, 576))

        result = pipe(
            image,
            num_frames=num_frames,
            decode_chunk_size=decode_chunk_size,
        )

        frames = result.frames[0]
        output_path = MODELS_DIR / "output" / f"svd_{int(time.time())}.mp4"
        output_path.parent.mkdir(parents=True, exist_ok=True)
        export_to_video(frames, str(output_path), fps=7)

        with open(output_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "video_base64": video_base64,
            "model": "stable_video_diffusion",
            "frames": num_frames,
            "video_path": str(output_path),
        }
    except Exception as e:
        return {"error": f"SVD generation failed: {str(e)}"}
    finally:
        try:
            del pipe
            if device == "cuda":
                torch.cuda.empty_cache()
        except Exception:
            pass


def style_transfer_animegan(params):
    """Apply AnimeGAN style transfer to an image."""
    import torch
    from PIL import Image
    import torchvision.transforms as transforms

    image_base64 = params.get("image_base64")
    if not image_base64:
        return {"error": "image_base64 is required for style transfer"}

    style = params.get("style", "face_paint_512_v2")
    model_dir = MODELS_DIR / "animegan_v3"

    device = get_device()

    try:
        # Try loading the model
        weight_file = model_dir / f"{style}.pt"
        if not weight_file.exists():
            # Try alternate names
            candidates = list(model_dir.glob("*.pt")) + list(model_dir.glob("*.pth"))
            if candidates:
                weight_file = candidates[0]
            else:
                return {"error": f"AnimeGAN weights not found. Run: python infer.py --download animegan_v3"}

        # Decode image
        img_bytes = base64.b64decode(image_base64)
        image = Image.open(BytesIO(img_bytes)).convert("RGB")

        # Load model - AnimeGAN2 uses a simple generator architecture
        model = torch.hub.load("bryandlee/animegan2-pytorch:main", "generator", pretrained=style)
        model = model.to(device).eval()

        face2paint = torch.hub.load("bryandlee/animegan2-pytorch:main", "face2paint", size=512)

        with torch.no_grad():
            output = face2paint(model, image)

        # Convert output to base64
        buf = BytesIO()
        output.save(buf, format="PNG")
        result_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {
            "success": True,
            "image_base64": result_base64,
            "model": "animegan_v3",
            "style": style,
        }
    except Exception as e:
        return {"error": f"Style transfer failed: {str(e)}"}


def _frames_to_video(frames, output_path):
    """Convert PIL frames to video using ffmpeg as fallback."""
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, frame in enumerate(frames):
            frame.save(os.path.join(tmpdir, f"frame_{i:04d}.png"))

        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-framerate", "8",
                "-i", os.path.join(tmpdir, "frame_%04d.png"),
                "-c:v", "libx264",
                "-pix_fmt", "yuv420p",
                "-preset", "fast",
                output_path,
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            return {"error": f"FFmpeg failed: {result.stderr[-200:]}"}

        with open(output_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "video_base64": video_base64,
            "video_path": output_path,
        }


def generate_video_animatediff_v3(params):
    """Generate video using AnimateDiff V3 with MotionLoRA camera control."""
    import torch

    model_dir = MODELS_DIR / "animatediff_v3"
    base_dir = MODELS_DIR / "sd15_base"

    if not model_dir.exists():
        return {"error": "AnimateDiff V3 not downloaded. Run: python infer.py --download animatediff_v3"}

    prompt = params.get("prompt", "")
    negative_prompt = params.get(
        "negative_prompt",
        "low quality, worst quality, bad anatomy, bad hands, missing fingers, "
        "extra digits, cropped, watermark, text, blurry, deformed, 3d, realistic photo",
    )
    num_frames = params.get("frames", 24)
    steps = params.get("steps", 25)
    guidance_scale = params.get("guidance_scale", 7.5)
    width = params.get("width", 512)
    height = params.get("height", 512)
    camera_motion = params.get("camera_motion")  # zoom_in, pan_left, tilt_up, etc.
    style_lora = params.get("style_lora")  # path to .safetensors
    style_lora_weight = params.get("style_lora_weight", 0.7)
    seed = params.get("seed")

    device = get_device()
    dtype = torch.float16 if device == "cuda" else torch.float32

    try:
        from diffusers import AnimateDiffPipeline, MotionAdapter, DDIMScheduler

        # Load V3 motion adapter
        adapter = MotionAdapter.from_pretrained(str(model_dir), torch_dtype=dtype)

        pipe = AnimateDiffPipeline.from_pretrained(
            str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
            motion_adapter=adapter,
            torch_dtype=dtype,
        )
        pipe.scheduler = DDIMScheduler.from_pretrained(
            str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
            subfolder="scheduler",
            clip_sample=False,
            timestep_spacing="linspace",
            beta_schedule="linear",
            steps_offset=1,
        )

        # Load MotionLoRA for camera movement if specified
        motion_lora_map = {
            "zoom_in": "guoyww/animatediff-motion-lora-zoom-in",
            "zoom_out": "guoyww/animatediff-motion-lora-zoom-out",
            "pan_left": "guoyww/animatediff-motion-lora-pan-left",
            "pan_right": "guoyww/animatediff-motion-lora-pan-right",
            "tilt_up": "guoyww/animatediff-motion-lora-tilt-up",
            "tilt_down": "guoyww/animatediff-motion-lora-tilt-down",
        }

        if camera_motion and camera_motion in motion_lora_map:
            try:
                pipe.load_lora_weights(
                    motion_lora_map[camera_motion],
                    adapter_name="camera",
                )
                pipe.set_adapters(["camera"], adapter_weights=[0.8])
                print(json.dumps({"progress": 0.1, "message": f"Loaded camera MotionLoRA: {camera_motion}"}), flush=True)
            except Exception as e:
                print(json.dumps({"progress": 0.1, "message": f"Camera MotionLoRA not available: {e}"}), flush=True)

        # Load optional style LoRA from user's lora directory
        loras_dir = Path.home() / ".opencli" / "models" / "loras"
        if style_lora and loras_dir.exists():
            lora_path = loras_dir / style_lora
            if lora_path.exists():
                try:
                    pipe.load_lora_weights(str(lora_path), adapter_name="style")
                    active = ["style"]
                    weights = [style_lora_weight]
                    if camera_motion and camera_motion in motion_lora_map:
                        active.insert(0, "camera")
                        weights.insert(0, 0.8)
                    pipe.set_adapters(active, adapter_weights=weights)
                    print(json.dumps({"progress": 0.15, "message": f"Loaded style LoRA: {style_lora}"}), flush=True)
                except Exception as e:
                    print(json.dumps({"progress": 0.15, "message": f"Style LoRA failed: {e}"}), flush=True)

        pipe = pipe.to(device)
        if device == "cuda":
            pipe.enable_model_cpu_offload()

        generator = None
        if seed is not None:
            generator = torch.Generator(device=device).manual_seed(seed)

        print(json.dumps({"progress": 0.2, "message": "Generating video frames..."}), flush=True)

        result = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_frames=num_frames,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
            width=width,
            height=height,
            generator=generator,
        )

        frames = result.frames[0]  # List of PIL Images

        output_path = MODELS_DIR / "output" / f"animatediff_v3_{int(time.time())}.mp4"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            from diffusers.utils import export_to_video
            export_to_video(frames, str(output_path), fps=12)
        except ImportError:
            return _frames_to_video(frames, str(output_path))

        with open(output_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "video_base64": video_base64,
            "model": "animatediff_v3",
            "frames": num_frames,
            "fps": 12,
            "width": width,
            "height": height,
            "camera_motion": camera_motion,
            "video_path": str(output_path),
        }
    except Exception as e:
        return {"error": f"AnimateDiff V3 generation failed: {str(e)}"}
    finally:
        try:
            del pipe, adapter
            if device == "cuda":
                torch.cuda.empty_cache()
        except Exception:
            pass


def upscale_realesrgan(params):
    """Upscale images or video frames using Real-ESRGAN anime model."""
    import torch
    import numpy as np
    from PIL import Image

    input_type = params.get("input_type", "image")  # image | video_frames
    scale = params.get("scale", 4)

    try:
        from realesrgan import RealESRGANer
        from basicsr.archs.rrdbnet_arch import RRDBNet

        # Use anime-optimized model (auto-downloads)
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=6, num_grow_ch=32, scale=4)

        # Try to find local weights first, otherwise auto-download
        weights_path = MODELS_DIR / "realesrgan" / "RealESRGAN_x4plus_anime_6B.pth"
        if not weights_path.exists():
            # Will auto-download from url
            model_url = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth"
        else:
            model_url = None

        device = get_device()
        # RealESRGANer handles device internally
        upsampler = RealESRGANer(
            scale=4,
            model_path=str(weights_path) if weights_path.exists() else model_url,
            model=model,
            tile=256,  # Tile-based to save VRAM
            tile_pad=10,
            pre_pad=0,
            half=device == "cuda",  # FP16 on CUDA only
        )

        if input_type == "image":
            image_base64 = params.get("image_base64")
            if not image_base64:
                return {"error": "image_base64 is required"}

            img_bytes = base64.b64decode(image_base64)
            img = Image.open(BytesIO(img_bytes)).convert("RGB")
            img_np = np.array(img)

            # BGR for OpenCV (Real-ESRGAN expects BGR)
            img_bgr = img_np[:, :, ::-1]
            output, _ = upsampler.enhance(img_bgr, outscale=scale)

            # Convert back to RGB PIL
            output_rgb = output[:, :, ::-1]
            output_img = Image.fromarray(output_rgb)

            buf = BytesIO()
            output_img.save(buf, format="PNG")
            result_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")

            return {
                "success": True,
                "image_base64": result_base64,
                "width": output_img.width,
                "height": output_img.height,
                "scale": scale,
            }

        elif input_type == "video_frames":
            frames_base64 = params.get("frames_base64", [])
            if not frames_base64:
                return {"error": "frames_base64 list is required"}

            upscaled_frames = []
            for i, fb64 in enumerate(frames_base64):
                img_bytes = base64.b64decode(fb64)
                img = Image.open(BytesIO(img_bytes)).convert("RGB")
                img_np = np.array(img)[:, :, ::-1]  # RGB -> BGR
                output, _ = upsampler.enhance(img_np, outscale=scale)
                output_rgb = output[:, :, ::-1]
                output_img = Image.fromarray(output_rgb)
                buf = BytesIO()
                output_img.save(buf, format="PNG")
                upscaled_frames.append(base64.b64encode(buf.getvalue()).decode("utf-8"))

                if (i + 1) % 5 == 0:
                    print(json.dumps({
                        "progress": (i + 1) / len(frames_base64),
                        "message": f"Upscaled {i + 1}/{len(frames_base64)} frames",
                    }), flush=True)

            return {
                "success": True,
                "frames_base64": upscaled_frames,
                "frame_count": len(upscaled_frames),
                "scale": scale,
            }

        else:
            return {"error": f"Unknown input_type: {input_type}"}

    except ImportError as e:
        return {"error": f"Real-ESRGAN not installed. Run: pip install realesrgan basicsr gfpgan. Details: {e}"}
    except Exception as e:
        return {"error": f"Upscale failed: {str(e)}"}


def interpolate_rife(params):
    """Interpolate video frames using rife-ncnn-vulkan for smooth motion."""
    import subprocess
    import tempfile
    import shutil

    video_path = params.get("video_path")
    if not video_path or not os.path.exists(video_path):
        return {"error": f"Video not found: {video_path}"}

    multiplier = params.get("multiplier", 2)  # 2x or 4x
    if multiplier not in (2, 4):
        multiplier = 2

    # Find rife-ncnn-vulkan binary
    rife_bin = shutil.which("rife-ncnn-vulkan")
    if not rife_bin:
        # Check common Homebrew path
        for candidate in ["/opt/homebrew/bin/rife-ncnn-vulkan", "/usr/local/bin/rife-ncnn-vulkan"]:
            if os.path.exists(candidate):
                rife_bin = candidate
                break
    if not rife_bin:
        return {"error": "rife-ncnn-vulkan not found. Install via: brew install rife-ncnn-vulkan"}

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            frames_dir = os.path.join(tmpdir, "frames")
            interp_dir = os.path.join(tmpdir, "interp")
            os.makedirs(frames_dir)
            os.makedirs(interp_dir)

            # Extract frames from video
            print(json.dumps({"progress": 0.1, "message": "Extracting frames..."}), flush=True)
            extract = subprocess.run([
                "ffmpeg", "-y", "-i", video_path,
                "-vsync", "0",
                os.path.join(frames_dir, "frame_%06d.png"),
            ], capture_output=True, text=True)

            if extract.returncode != 0:
                return {"error": f"Frame extraction failed: {extract.stderr[-200:]}"}

            frame_count = len([f for f in os.listdir(frames_dir) if f.endswith(".png")])
            if frame_count < 2:
                return {"error": "Not enough frames to interpolate"}

            # Get original fps
            probe = subprocess.run([
                "ffprobe", "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=r_frame_rate",
                "-of", "default=noprint_wrappers=1:nokey=1",
                video_path,
            ], capture_output=True, text=True)
            fps_str = probe.stdout.strip()
            try:
                if "/" in fps_str:
                    num, den = fps_str.split("/")
                    orig_fps = float(num) / float(den)
                else:
                    orig_fps = float(fps_str)
            except (ValueError, ZeroDivisionError):
                orig_fps = 12.0

            target_fps = orig_fps * multiplier

            # Run RIFE interpolation
            print(json.dumps({"progress": 0.3, "message": f"Interpolating {frame_count} frames ({multiplier}x)..."}), flush=True)

            # rife-ncnn-vulkan expects numbered frames in input dir
            rife_args = [
                rife_bin,
                "-i", frames_dir,
                "-o", interp_dir,
                "-m", "rife-v4.6",  # Latest model
            ]
            # For 4x, run RIFE twice (2x -> 2x)
            if multiplier == 4:
                # First pass: 2x
                interp_dir_1 = os.path.join(tmpdir, "interp1")
                os.makedirs(interp_dir_1)
                r1 = subprocess.run(
                    [rife_bin, "-i", frames_dir, "-o", interp_dir_1, "-m", "rife-v4.6"],
                    capture_output=True, text=True, timeout=300,
                )
                if r1.returncode != 0:
                    return {"error": f"RIFE pass 1 failed: {r1.stderr[-200:]}"}

                print(json.dumps({"progress": 0.5, "message": "RIFE pass 2..."}), flush=True)
                r2 = subprocess.run(
                    [rife_bin, "-i", interp_dir_1, "-o", interp_dir, "-m", "rife-v4.6"],
                    capture_output=True, text=True, timeout=300,
                )
                if r2.returncode != 0:
                    return {"error": f"RIFE pass 2 failed: {r2.stderr[-200:]}"}
            else:
                r = subprocess.run(rife_args, capture_output=True, text=True, timeout=300)
                if r.returncode != 0:
                    return {"error": f"RIFE failed: {r.stderr[-200:]}"}

            # Reassemble video at target fps
            print(json.dumps({"progress": 0.8, "message": "Reassembling video..."}), flush=True)
            output_path = str(MODELS_DIR / "output" / f"rife_{int(time.time())}.mp4")
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # Get interp frame pattern
            interp_frames = sorted([f for f in os.listdir(interp_dir) if f.endswith(".png")])
            if not interp_frames:
                return {"error": "No interpolated frames produced"}

            assemble = subprocess.run([
                "ffmpeg", "-y",
                "-framerate", str(target_fps),
                "-i", os.path.join(interp_dir, "%06d.png"),
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "18",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                output_path,
            ], capture_output=True, text=True)

            if assemble.returncode != 0:
                return {"error": f"Reassembly failed: {assemble.stderr[-200:]}"}

            with open(output_path, "rb") as f:
                video_base64 = base64.b64encode(f.read()).decode("utf-8")

            new_frame_count = len(interp_frames)

            return {
                "success": True,
                "video_base64": video_base64,
                "video_path": output_path,
                "original_fps": orig_fps,
                "target_fps": target_fps,
                "original_frames": frame_count,
                "interpolated_frames": new_frame_count,
                "multiplier": multiplier,
            }

    except subprocess.TimeoutExpired:
        return {"error": "RIFE interpolation timed out (5 minutes)"}
    except Exception as e:
        return {"error": f"Interpolation failed: {str(e)}"}


def extract_control_signal(params):
    """Extract lineart/depth/openpose control signal from a reference image."""
    from PIL import Image

    image_base64 = params.get("image_base64")
    if not image_base64:
        return {"error": "image_base64 is required"}

    control_type = params.get("control_type", "lineart_anime")

    try:
        img_bytes = base64.b64decode(image_base64)
        image = Image.open(BytesIO(img_bytes)).convert("RGB")

        if control_type == "lineart_anime":
            from controlnet_aux import LineartAnimeDetector
            detector = LineartAnimeDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(image)
        elif control_type == "openpose":
            from controlnet_aux import OpenposeDetector
            detector = OpenposeDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(image)
        elif control_type == "depth":
            from controlnet_aux import MidasDetector
            detector = MidasDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(image)
        else:
            return {"error": f"Unknown control type: {control_type}"}

        buf = BytesIO()
        control_image.save(buf, format="PNG")
        result_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {
            "success": True,
            "control_image_base64": result_base64,
            "control_type": control_type,
            "width": control_image.width,
            "height": control_image.height,
        }
    except ImportError as e:
        return {"error": f"controlnet-aux not installed: {e}. Run: pip install controlnet-aux"}
    except Exception as e:
        return {"error": f"Control signal extraction failed: {str(e)}"}


def generate_controlnet_video(params):
    """Hybrid pipeline: reference keyframe -> lineart -> SD1.5+ControlNet+AnimateDiff V3."""
    import torch
    from PIL import Image

    reference_base64 = params.get("reference_image_base64")
    if not reference_base64:
        return {"error": "reference_image_base64 is required"}

    prompt = params.get("prompt", "")
    negative_prompt = params.get(
        "negative_prompt",
        "low quality, worst quality, bad anatomy, blurry, deformed",
    )
    control_type = params.get("control_type", "lineart_anime")
    camera_motion = params.get("camera_motion")
    style_lora = params.get("style_lora")
    style_lora_weight = params.get("style_lora_weight", 0.7)
    controlnet_scale = params.get("controlnet_conditioning_scale", 0.7)
    num_frames = params.get("frames", 24)
    width = params.get("width", 512)
    height = params.get("height", 512)
    steps = params.get("steps", 25)
    seed = params.get("seed")

    device = get_device()
    dtype = torch.float16 if device == "cuda" else torch.float32

    base_dir = MODELS_DIR / "sd15_base"
    v3_dir = MODELS_DIR / "animatediff_v3"

    # Resolve ControlNet model path
    cn_model_map = {
        "lineart_anime": "controlnet_lineart_anime",
        "openpose": "controlnet_openpose",
        "depth": "controlnet_depth",
    }
    cn_model_id = cn_model_map.get(control_type)
    if not cn_model_id:
        return {"error": f"Unknown control type: {control_type}"}

    cn_dir = MODELS_DIR / cn_model_id
    if not cn_dir.exists():
        return {"error": f"ControlNet model not downloaded: {cn_model_id}"}

    if not v3_dir.exists():
        return {"error": "AnimateDiff V3 not downloaded"}

    try:
        # Step 1: Load and resize reference image
        print(json.dumps({"progress": 0.05, "message": "Loading reference image..."}), flush=True)
        img_bytes = base64.b64decode(reference_base64)
        ref_image = Image.open(BytesIO(img_bytes)).convert("RGB")
        ref_image = ref_image.resize((width, height), Image.LANCZOS)

        # Step 2: Extract control signal
        print(json.dumps({"progress": 0.1, "message": f"Extracting {control_type} control..."}), flush=True)

        if control_type == "lineart_anime":
            from controlnet_aux import LineartAnimeDetector
            detector = LineartAnimeDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(ref_image)
        elif control_type == "openpose":
            from controlnet_aux import OpenposeDetector
            detector = OpenposeDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(ref_image)
        elif control_type == "depth":
            from controlnet_aux import MidasDetector
            detector = MidasDetector.from_pretrained("lllyasviel/Annotators")
            control_image = detector(ref_image)

        del detector  # Free memory

        # Step 3: Load ControlNet + AnimateDiff pipeline
        print(json.dumps({"progress": 0.15, "message": "Loading ControlNet + AnimateDiff V3..."}), flush=True)

        from diffusers import ControlNetModel, MotionAdapter, DDIMScheduler

        controlnet = ControlNetModel.from_pretrained(str(cn_dir), torch_dtype=dtype)
        adapter = MotionAdapter.from_pretrained(str(v3_dir), torch_dtype=dtype)

        # Try AnimateDiffControlNetPipeline first, fallback to manual setup
        try:
            from diffusers import AnimateDiffControlNetPipeline

            pipe = AnimateDiffControlNetPipeline.from_pretrained(
                str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
                controlnet=controlnet,
                motion_adapter=adapter,
                torch_dtype=dtype,
            )
        except ImportError:
            # Fallback: Use standard AnimateDiffPipeline (no ControlNet guidance)
            from diffusers import AnimateDiffPipeline

            pipe = AnimateDiffPipeline.from_pretrained(
                str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
                motion_adapter=adapter,
                torch_dtype=dtype,
            )
            print(json.dumps({"progress": 0.2, "message": "Fallback: AnimateDiff without ControlNet (update diffusers for full support)"}), flush=True)

        pipe.scheduler = DDIMScheduler.from_pretrained(
            str(base_dir) if base_dir.exists() else "runwayml/stable-diffusion-v1-5",
            subfolder="scheduler",
            clip_sample=False,
            timestep_spacing="linspace",
            beta_schedule="linear",
            steps_offset=1,
        )

        # Step 4: Load MotionLoRA for camera
        motion_lora_map = {
            "zoom_in": "guoyww/animatediff-motion-lora-zoom-in",
            "zoom_out": "guoyww/animatediff-motion-lora-zoom-out",
            "pan_left": "guoyww/animatediff-motion-lora-pan-left",
            "pan_right": "guoyww/animatediff-motion-lora-pan-right",
            "tilt_up": "guoyww/animatediff-motion-lora-tilt-up",
            "tilt_down": "guoyww/animatediff-motion-lora-tilt-down",
        }

        active_adapters = []
        adapter_weights = []

        if camera_motion and camera_motion in motion_lora_map:
            try:
                pipe.load_lora_weights(motion_lora_map[camera_motion], adapter_name="camera")
                active_adapters.append("camera")
                adapter_weights.append(0.8)
                print(json.dumps({"progress": 0.22, "message": f"Loaded camera MotionLoRA: {camera_motion}"}), flush=True)
            except Exception as e:
                print(json.dumps({"progress": 0.22, "message": f"Camera LoRA skipped: {e}"}), flush=True)

        # Load optional style LoRA
        loras_dir = Path.home() / ".opencli" / "models" / "loras"
        if style_lora and loras_dir.exists():
            lora_path = loras_dir / style_lora
            if lora_path.exists():
                try:
                    pipe.load_lora_weights(str(lora_path), adapter_name="style")
                    active_adapters.append("style")
                    adapter_weights.append(style_lora_weight)
                except Exception as e:
                    print(json.dumps({"progress": 0.23, "message": f"Style LoRA skipped: {e}"}), flush=True)

        if active_adapters:
            pipe.set_adapters(active_adapters, adapter_weights=adapter_weights)

        pipe = pipe.to(device)
        if device == "cuda":
            pipe.enable_model_cpu_offload()

        generator = None
        if seed is not None:
            generator = torch.Generator(device=device).manual_seed(seed)

        # Step 5: Generate video frames
        print(json.dumps({"progress": 0.3, "message": "Generating video frames with ControlNet guidance..."}), flush=True)

        # Build kwargs — include conditioning_frames for ControlNet pipeline
        gen_kwargs = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "num_frames": num_frames,
            "num_inference_steps": steps,
            "guidance_scale": 7.5,
            "width": width,
            "height": height,
            "generator": generator,
        }

        # Add ControlNet conditioning if pipeline supports it
        if hasattr(pipe, "controlnet") and pipe.controlnet is not None:
            # Provide same control image for all frames
            gen_kwargs["conditioning_frames"] = [control_image] * num_frames

        result = pipe(**gen_kwargs)
        frames = result.frames[0]

        # Step 6: Export to MP4
        print(json.dumps({"progress": 0.9, "message": "Encoding video..."}), flush=True)
        output_path = MODELS_DIR / "output" / f"controlnet_video_{int(time.time())}.mp4"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            from diffusers.utils import export_to_video
            export_to_video(frames, str(output_path), fps=12)
        except ImportError:
            return _frames_to_video(frames, str(output_path))

        with open(output_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "success": True,
            "video_base64": video_base64,
            "model": "controlnet_animatediff_v3",
            "control_type": control_type,
            "frames": num_frames,
            "fps": 12,
            "width": width,
            "height": height,
            "camera_motion": camera_motion,
            "controlnet_conditioning_scale": controlnet_scale,
            "video_path": str(output_path),
        }

    except Exception as e:
        return {"error": f"ControlNet video generation failed: {str(e)}"}
    finally:
        try:
            del pipe, adapter, controlnet
            if device == "cuda":
                torch.cuda.empty_cache()
        except Exception:
            pass


def upscale_video_path(params):
    """Upscale a video file frame-by-frame using Real-ESRGAN."""
    import torch
    import numpy as np
    import subprocess
    import tempfile
    from PIL import Image

    video_path = params.get("video_path")
    if not video_path or not os.path.exists(video_path):
        return {"error": f"Video not found: {video_path}"}

    scale = params.get("scale", 4)

    try:
        from realesrgan import RealESRGANer
        from basicsr.archs.rrdbnet_arch import RRDBNet

        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=6, num_grow_ch=32, scale=4)
        weights_path = MODELS_DIR / "realesrgan" / "RealESRGAN_x4plus_anime_6B.pth"
        model_url = None if weights_path.exists() else \
            "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth"

        device = get_device()
        upsampler = RealESRGANer(
            scale=4,
            model_path=str(weights_path) if weights_path.exists() else model_url,
            model=model,
            tile=256,
            tile_pad=10,
            pre_pad=0,
            half=device == "cuda",
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            frames_dir = os.path.join(tmpdir, "frames")
            upscaled_dir = os.path.join(tmpdir, "upscaled")
            os.makedirs(frames_dir)
            os.makedirs(upscaled_dir)

            # Extract frames
            print(json.dumps({"progress": 0.05, "message": "Extracting frames..."}), flush=True)
            subprocess.run([
                "ffmpeg", "-y", "-i", video_path,
                "-vsync", "0",
                os.path.join(frames_dir, "frame_%06d.png"),
            ], capture_output=True, text=True)

            # Get fps
            probe = subprocess.run([
                "ffprobe", "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=r_frame_rate",
                "-of", "default=noprint_wrappers=1:nokey=1",
                video_path,
            ], capture_output=True, text=True)
            fps_str = probe.stdout.strip()
            try:
                if "/" in fps_str:
                    num, den = fps_str.split("/")
                    fps = float(num) / float(den)
                else:
                    fps = float(fps_str)
            except (ValueError, ZeroDivisionError):
                fps = 12.0

            frame_files = sorted([f for f in os.listdir(frames_dir) if f.endswith(".png")])
            total = len(frame_files)
            if total == 0:
                return {"error": "No frames extracted from video"}

            # Upscale each frame
            for i, fname in enumerate(frame_files):
                img = Image.open(os.path.join(frames_dir, fname)).convert("RGB")
                img_bgr = np.array(img)[:, :, ::-1]
                output, _ = upsampler.enhance(img_bgr, outscale=scale)
                output_rgb = output[:, :, ::-1]
                Image.fromarray(output_rgb).save(os.path.join(upscaled_dir, fname))

                if (i + 1) % 5 == 0 or i == total - 1:
                    pct = 0.1 + (i + 1) / total * 0.8
                    print(json.dumps({
                        "progress": pct,
                        "message": f"Upscaled {i + 1}/{total} frames",
                    }), flush=True)

            # Reassemble
            print(json.dumps({"progress": 0.92, "message": "Reassembling video..."}), flush=True)
            output_path = str(MODELS_DIR / "output" / f"upscaled_{int(time.time())}.mp4")
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            subprocess.run([
                "ffmpeg", "-y",
                "-framerate", str(fps),
                "-i", os.path.join(upscaled_dir, "frame_%06d.png"),
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "18",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                output_path,
            ], capture_output=True, text=True)

            with open(output_path, "rb") as f:
                video_base64 = base64.b64encode(f.read()).decode("utf-8")

            return {
                "success": True,
                "video_base64": video_base64,
                "video_path": output_path,
                "frames": total,
                "scale": scale,
            }

    except ImportError as e:
        return {"error": f"Real-ESRGAN not installed: {e}"}
    except Exception as e:
        return {"error": f"Video upscale failed: {str(e)}"}


def handle_stdin():
    """Read JSON from stdin and dispatch action."""
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON: {str(e)}"}

    action = data.get("action", "")

    if action == "check_env":
        return check_environment()
    elif action == "list_models":
        return list_models()
    elif action == "model_status":
        return get_model_status(data.get("model_id", ""))
    elif action == "download":
        return download_model(data.get("model_id", ""))
    elif action == "generate_image":
        return generate_image(data)
    elif action == "generate_video":
        model = data.get("model", "animatediff")
        if model == "stable_video_diffusion":
            return generate_video_svd(data)
        else:
            return generate_video_animatediff(data)
    elif action == "generate_video_v3":
        return generate_video_animatediff_v3(data)
    elif action == "upscale":
        return upscale_realesrgan(data)
    elif action == "interpolate":
        return interpolate_rife(data)
    elif action == "style_transfer":
        return style_transfer_animegan(data)
    elif action == "extract_control":
        return extract_control_signal(data)
    elif action == "generate_controlnet_video":
        return generate_controlnet_video(data)
    elif action == "upscale_video_path":
        return upscale_video_path(data)
    else:
        return {"error": f"Unknown action: {action}"}


def main():
    parser = argparse.ArgumentParser(description="OpenCLI Local Inference Engine")
    parser.add_argument("--check-env", action="store_true", help="Check environment")
    parser.add_argument("--list-models", action="store_true", help="List all models")
    parser.add_argument("--model-status", type=str, help="Check model download status")
    parser.add_argument("--download", type=str, help="Download a model")
    parser.add_argument("--stdin", action="store_true", help="Read JSON from stdin")
    args = parser.parse_args()

    if args.check_env:
        print(json.dumps(check_environment(), indent=2))
    elif args.list_models:
        print(json.dumps(list_models(), indent=2))
    elif args.model_status:
        print(json.dumps(get_model_status(args.model_status), indent=2))
    elif args.download:
        result = download_model(args.download)
        print(json.dumps(result, indent=2))
    elif args.stdin or not sys.stdin.isatty():
        result = handle_stdin()
        print(json.dumps(result))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
