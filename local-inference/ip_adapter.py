#!/usr/bin/env python3
"""
OpenCLI IP-Adapter wrapper for character consistency.

Uses IP-Adapter FaceID to maintain character appearance across scenes.
Reads JSON from stdin, generates images with reference embedding, writes JSON to stdout.

Actions:
  encode_reference   — Extract CLIP embedding from reference face image
  generate_with_reference — SD1.5 + IP-Adapter conditioned generation
  list_references    — List saved reference images for a character

Requires: pip install ip-adapter diffusers transformers torch
"""

import base64
import json
import os
import sys
import time
from io import BytesIO
from pathlib import Path

MODELS_DIR = Path.home() / ".opencli" / "models"
REFS_DIR = MODELS_DIR / "ip_adapter_face" / "references"
EMBEDDINGS_DIR = MODELS_DIR / "ip_adapter_face" / "embeddings"


def encode_reference(params: dict) -> dict:
    """Encode a reference image into a CLIP vision embedding for IP-Adapter."""
    try:
        import torch
        from PIL import Image

        image_base64 = params.get("image_base64")
        character_id = params.get("character_id", "unknown")
        if not image_base64:
            return {"success": False, "error": "No image_base64 provided"}

        img_bytes = base64.b64decode(image_base64)
        image = Image.open(BytesIO(img_bytes)).convert("RGB")

        # Save reference image
        REFS_DIR.mkdir(parents=True, exist_ok=True)
        EMBEDDINGS_DIR.mkdir(parents=True, exist_ok=True)

        ref_id = f"ref_{character_id}_{int(time.time())}"
        ref_path = REFS_DIR / f"{ref_id}.png"
        image.save(str(ref_path))

        # Try CLIP vision encoding for IP-Adapter
        embedding_path = str(EMBEDDINGS_DIR / f"{ref_id}.pt")
        has_clip_embedding = False

        try:
            from transformers import CLIPVisionModelWithProjection, CLIPImageProcessor

            device = _get_device()
            dtype = torch.float16 if device == "cuda" else torch.float32

            # Use CLIP ViT-H/14 (same as IP-Adapter uses)
            clip_model = CLIPVisionModelWithProjection.from_pretrained(
                "laion/CLIP-ViT-H-14-laion2B-s32B-b79K",
                torch_dtype=dtype,
            ).to(device)
            clip_processor = CLIPImageProcessor.from_pretrained(
                "laion/CLIP-ViT-H-14-laion2B-s32B-b79K"
            )

            # Process image → CLIP embedding [1, 1024]
            inputs = clip_processor(images=image, return_tensors="pt").to(device, dtype)
            outputs = clip_model(**inputs)
            image_embeds = outputs.image_embeds  # [1, 1024]

            torch.save(image_embeds.cpu(), embedding_path)
            has_clip_embedding = True

            del clip_model, clip_processor
            _cleanup_gpu()

            print(f"[IP-Adapter] CLIP embedding saved: {embedding_path}", file=sys.stderr)

        except (ImportError, Exception) as e:
            print(f"[IP-Adapter] CLIP encoding skipped ({e}), using image-only reference", file=sys.stderr)
            embedding_path = str(ref_path)  # Fall back to image path

        return {
            "success": True,
            "embedding_path": embedding_path,
            "reference_path": str(ref_path),
            "reference_id": ref_id,
            "character_id": character_id,
            "has_clip_embedding": has_clip_embedding,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def generate_with_reference(params: dict) -> dict:
    """Generate an image using IP-Adapter with a reference embedding."""
    pipe = None
    try:
        import torch
        from PIL import Image

        embedding_path = params.get("embedding_path")
        reference_path = params.get("reference_path")
        prompt = params.get("prompt", "")
        negative_prompt = params.get("negative_prompt", "low quality, blurry, bad anatomy")
        width = params.get("width", 512)
        height = params.get("height", 512)
        steps = params.get("steps", 30)
        ip_adapter_scale = params.get("ip_adapter_scale", 0.6)

        # Need at least a reference image
        ref_image_path = reference_path or embedding_path
        if not ref_image_path or not os.path.exists(ref_image_path):
            return {"success": False, "error": f"Reference not found: {ref_image_path}"}

        device = _get_device()
        dtype = torch.float16 if device == "cuda" else torch.float32

        # Find base model (SD1.5 for IP-Adapter compatibility)
        model_dir = _find_sd15_model()
        if model_dir is None:
            return {"success": False, "error": "No SD1.5 base model. Download waifu_diffusion first."}

        # Try full IP-Adapter pipeline
        try:
            from diffusers import StableDiffusionPipeline

            pipe = StableDiffusionPipeline.from_pretrained(
                str(model_dir), torch_dtype=dtype, use_safetensors=True
            ).to(device)

            # Load IP-Adapter weights
            ip_adapter_dir = MODELS_DIR / "ip_adapter_face"
            ip_adapter_weights = ip_adapter_dir / "ip-adapter-full-face_sd15.bin"

            if ip_adapter_weights.exists():
                pipe.load_ip_adapter(
                    str(ip_adapter_dir),
                    weight_name="ip-adapter-full-face_sd15.bin",
                    subfolder="",
                )
                pipe.set_ip_adapter_scale(ip_adapter_scale)

                # Check for CLIP embedding
                if embedding_path and embedding_path.endswith(".pt") and os.path.exists(embedding_path):
                    image_embeds = torch.load(embedding_path, weights_only=True).to(device, dtype)
                    result = pipe(
                        prompt=prompt,
                        negative_prompt=negative_prompt,
                        ip_adapter_image_embeds=[image_embeds],
                        num_inference_steps=steps,
                        width=width,
                        height=height,
                    )
                else:
                    # Use reference image directly
                    ref_image = Image.open(ref_image_path).convert("RGB").resize((224, 224))
                    result = pipe(
                        prompt=prompt,
                        negative_prompt=negative_prompt,
                        ip_adapter_image=ref_image,
                        num_inference_steps=steps,
                        width=width,
                        height=height,
                    )

                output_image = result.images[0]
                return _image_to_response(output_image, width, height, embedding_path, "ip_adapter")

            else:
                print("[IP-Adapter] No IP-Adapter weights found, using img2img fallback", file=sys.stderr)
                raise FileNotFoundError("IP-Adapter weights not downloaded")

        except (ImportError, FileNotFoundError, Exception) as e:
            print(f"[IP-Adapter] Full IP-Adapter unavailable ({e}), using img2img", file=sys.stderr)

            # Fallback: img2img with reference image
            if pipe is not None:
                del pipe
                _cleanup_gpu()

            from diffusers import StableDiffusionImg2ImgPipeline

            pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
                str(model_dir), torch_dtype=dtype, use_safetensors=True
            ).to(device)

            ref_image = Image.open(ref_image_path).convert("RGB").resize((width, height))

            strength = 1.0 - ip_adapter_scale  # Higher scale = lower strength = more reference
            result = pipe(
                prompt=prompt,
                image=ref_image,
                strength=max(0.2, min(0.8, strength)),
                negative_prompt=negative_prompt,
                num_inference_steps=steps,
            )

            output_image = result.images[0]
            return _image_to_response(output_image, width, height, ref_image_path, "img2img_fallback")

    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if pipe is not None:
            del pipe
        _cleanup_gpu()


def list_references(params: dict) -> dict:
    """List saved reference images for a character."""
    try:
        character_id = params.get("character_id")
        refs = []

        if REFS_DIR.exists():
            for f in sorted(REFS_DIR.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True):
                name = f.stem
                if character_id and character_id not in name:
                    continue

                # Check for corresponding embedding
                emb_path = EMBEDDINGS_DIR / f"{name}.pt"
                refs.append({
                    "id": name,
                    "path": str(f),
                    "has_embedding": emb_path.exists(),
                    "embedding_path": str(emb_path) if emb_path.exists() else None,
                    "created_at": int(f.stat().st_mtime),
                })

        return {"success": True, "references": refs, "count": len(refs)}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ── Helpers ──

def _get_device() -> str:
    import torch
    if torch.cuda.is_available():
        return "cuda"
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def _find_sd15_model():
    """Find a suitable SD1.5 base model for IP-Adapter."""
    for name in ["waifu_diffusion", "animagine_xl"]:
        p = MODELS_DIR / name
        if p.exists():
            return p
    return None


def _image_to_response(image, width, height, ref_path, method):
    """Convert PIL image to JSON response."""
    buf = BytesIO()
    image.save(buf, format="PNG")
    img_base64 = base64.b64encode(buf.getvalue()).decode("utf-8")
    return {
        "success": True,
        "image_base64": img_base64,
        "width": width,
        "height": height,
        "reference_used": ref_path,
        "method": method,
    }


def _cleanup_gpu():
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        import gc
        gc.collect()
    except Exception:
        pass


def main():
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        print(json.dumps({"success": False, "error": f"Invalid JSON: {e}"}))
        return

    action = data.get("action", "")

    if action == "encode_reference":
        result = encode_reference(data)
    elif action == "generate_with_reference":
        result = generate_with_reference(data)
    elif action == "list_references":
        result = list_references(data)
    else:
        result = {"success": False, "error": f"Unknown action: {action}"}

    print(json.dumps(result))


if __name__ == "__main__":
    main()
