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

        # For AnimateDiff, download both motion adapter and base model
        if model_id == "animatediff":
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
    dtype = torch.float16 if device != "cpu" else torch.float32

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
    dtype = torch.float16 if device != "cpu" else torch.float32

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
    dtype = torch.float16 if device != "cpu" else torch.float32

    try:
        from diffusers import StableVideoDiffusionPipeline
        from diffusers.utils import export_to_video

        pipe = StableVideoDiffusionPipeline.from_pretrained(
            str(model_dir), torch_dtype=dtype, variant="fp16" if device != "cpu" else None
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
    elif action == "style_transfer":
        return style_transfer_animegan(data)
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
