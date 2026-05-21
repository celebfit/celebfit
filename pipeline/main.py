import os
import sys
import torch
import cv2
import numpy as np
from PIL import Image

# Ensure we can import local modules
root_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_path)

from util.smooth_mask import smooth_mask
from util.dilate_mask import dilate_mask
from util.crop_face import get_crop_info, apply_crop, restore_crop
from masking_bisenet.generate_mask_bisenet import generate_bisenet_face_parts_mask
from diffusers import StableDiffusionInpaintPipeline, UniPCMultistepScheduler, UNet2DConditionModel, AutoencoderKL
from transformers import CLIPTextModel, CLIPTokenizer
from peft import PeftModel

#======= Configuration
# Base realistic checkpoint (automatically cached from HuggingFace)
base_model_path = "emilianJR/epiCRealism" 

# Choose target celebrity: '고윤정' (Go Youn Jung), '신세경' (Shin Se Kyung), or '홍수주' (Hong Su Zu)
TARGET_CELEB = "고윤정"

# Inputs
image_path = os.path.join(root_path, "data/raw_face_data/seed1056395.png")
output_path = os.path.join(root_path, "pipeline/result_face.png")

# Inpainting Hyperparameters
STABLE_STRENGTH = 0.50
STABLE_LORA_SCALE = 0.90

# Prompt construction
prompt = f"a photo of {TARGET_CELEB} style eyebrows, highly detailed, natural hair texture, masterpiece, 8k uhd"
negative_prompt = "low quality, distorted, blurry, messy, ugly, asymmetric eyebrows, double eyebrows, painted, drawing, illustration, cartoon, fake, 3d render, smooth skin, purple patches, colorful noise, hard edges"

#======= Device Setup (Mac MPS / CUDA / CPU)
if torch.cuda.is_available():
    device = "cuda"
    dtype = torch.float16
elif torch.backends.mps.is_available():
    device = "mps"
    dtype = torch.float32
else:
    device = "cpu"
    dtype = torch.float32

def run_pipeline():
    #======= 1. Load Models & Pipelines
    print(f"Loading base model {base_model_path} on {device}...")
    
    text_encoder = CLIPTextModel.from_pretrained(base_model_path, subfolder="text_encoder", torch_dtype=dtype)
    vae = AutoencoderKL.from_pretrained(base_model_path, subfolder="vae", torch_dtype=dtype)
    unet = UNet2DConditionModel.from_pretrained(base_model_path, subfolder="unet", torch_dtype=dtype)
    
    pipe = StableDiffusionInpaintPipeline.from_pretrained(
        base_model_path, text_encoder=text_encoder, vae=vae, unet=unet,
        torch_dtype=dtype, low_cpu_mem_usage=True, safety_checker=None
    )
    pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
    pipe.to(device)

    #======= 2. Load Unified/Individual LoRA
    # Check for the unified LoRA model first, fallback to individual if not trained yet
    unified_lora_path = os.path.join(root_path, "data/ckpt/celeb_eyebrows_all_pro_v2")
    individual_lora_path = os.path.join(root_path, f"data/ckpt/{TARGET_CELEB}_eyebrows_pro_v2")
    
    if os.path.exists(os.path.join(unified_lora_path, "unet")):
        pipe.unet = PeftModel.from_pretrained(pipe.unet, os.path.join(unified_lora_path, "unet"), adapter_name="celebs")
        pipe.text_encoder = PeftModel.from_pretrained(pipe.text_encoder, os.path.join(unified_lora_path, "text_encoder"), adapter_name="celebs")
        pipe.set_adapters(["celebs"], adapter_weights=[STABLE_LORA_SCALE])
        print(f"✅ Loaded Unified LoRA Adapter with scale {STABLE_LORA_SCALE}")
    elif os.path.exists(os.path.join(individual_lora_path, "unet")):
        pipe.unet = PeftModel.from_pretrained(pipe.unet, os.path.join(individual_lora_path, "unet"), adapter_name="celebs")
        pipe.text_encoder = PeftModel.from_pretrained(pipe.text_encoder, os.path.join(individual_lora_path, "text_encoder"), adapter_name="celebs")
        pipe.set_adapters(["celebs"], adapter_weights=[STABLE_LORA_SCALE])
        print(f"✅ Loaded Individual {TARGET_CELEB} LoRA Adapter with scale {STABLE_LORA_SCALE}")
    else:
        print("⚠️ Warning: No pre-trained LoRA adapter found in data/ckpt/. Proceeding without LoRA.")

    #======= 3. Prepare Image & Generate Mask
    print(f"Generating eyebrows mask for: {TARGET_CELEB}")
    original_bgr = cv2.imread(image_path)
    if original_bgr is None:
        print(f"Error: Could not find input image at {image_path}")
        return

    # Generate eyebrow mask using BiSeNet
    raw_mask = generate_bisenet_face_parts_mask(original_bgr, parts=["eyebrows"])
    processed_mask = smooth_mask(raw_mask)
    processed_mask = dilate_mask(processed_mask, pixels=4)

    # Crop target face area locally for stable generation scale (resolves scale mismatch)
    h, w = original_bgr.shape[:2]
    crop_info = get_crop_info(processed_mask, original_bgr.shape, target_size=512)
    
    # 512x512 Local Crops
    image_512 = apply_crop(original_bgr, crop_info, target_size=512)
    mask_512 = apply_crop(processed_mask, crop_info, target_size=512)
    
    # Preprocess Image & Mask for Pipeline
    image_pil = Image.fromarray(cv2.cvtColor(image_512, cv2.COLOR_BGR2RGB))
    mask_pil = Image.fromarray(mask_512).convert("L")

    #======= 4. Inference
    print(f"Inpainting new eyebrows via StableDiffusionInpaintPipeline (Strength: {STABLE_STRENGTH})...")
    generator = torch.Generator(device).manual_seed(42)
    
    # Enable LoRA scaling safely
    pipe.unet.set_adapter("celebs")
    pipe.text_encoder.set_adapter("celebs")

    output_512_pil = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=image_pil,
        mask_image=mask_pil,
        strength=STABLE_STRENGTH,
        num_inference_steps=25,
        generator=generator
    ).images[0]

    #======= 5. Integrate & Restore Back to Full Image
    output_512_bgr = cv2.cvtColor(np.array(output_512_pil), cv2.COLOR_RGB2BGR)
    
    # Restore the local 512 patch back to original resolution
    restored_full = restore_crop(output_512_bgr, crop_info, original_bgr.shape)
    restored_mask = restore_crop(mask_512, crop_info, original_bgr.shape)

    # Soft alpha-blending
    mask_np = restored_mask.astype(np.float32) / 255.0
    if len(mask_np.shape) == 2:
        mask_np = mask_np[:, :, np.newaxis]
    mask_blurred = cv2.GaussianBlur(mask_np, (15, 15), 0)
    if len(mask_blurred.shape) == 2:
        mask_blurred = mask_blurred[:, :, np.newaxis]

    final_np = (restored_full * mask_blurred + original_bgr * (1.0 - mask_blurred)).astype(np.uint8)

    #======= 6. Create Preview & Save
    scale = 0.5
    new_size = (int(w * scale), int(h * scale))
    preview_orig = cv2.resize(original_bgr, new_size)
    preview_mask = cv2.resize(cv2.cvtColor(processed_mask, cv2.COLOR_GRAY2BGR), new_size)
    preview_res = cv2.resize(final_np, new_size)

    comparison = np.hstack((preview_orig, preview_mask, preview_res))
    cv2.imwrite(output_path, comparison)
    print(f"🎉 Success! Result saved to {output_path}")

if __name__ == "__main__":
    run_pipeline()
