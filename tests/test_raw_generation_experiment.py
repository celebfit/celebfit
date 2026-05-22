import os
import sys
import torch
import cv2
import numpy as np
from PIL import Image

# Ensure we can import local modules
root_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_path)
sys.path.insert(0, os.path.join(root_path, "brushnet/src"))

from masking_bisenet.generate_mask_bisenet import generate_bisenet_face_parts_mask
from util.dilate_mask import dilate_mask
from util.smooth_mask import smooth_mask
from util.crop_face import get_actor_face_crop_info, apply_crop, restore_crop
from diffusers import StableDiffusionInpaintPipeline, UniPCMultistepScheduler, UNet2DConditionModel, AutoencoderKL
from transformers import CLIPTextModel
import transformers

if not hasattr(transformers, 'CLIPFeatureExtractor'):
    transformers.CLIPFeatureExtractor = transformers.CLIPImageProcessor

#======= Configuration
base_model_path = "emilianJR/epiCRealism" 
v4_lora_path = os.path.join(root_path, "lora_checkpoint/celeb_eyebrows_all_pro_v4")
input_images_dir = os.path.join(root_path, "data/raw_face_data")
output_dir = os.path.join(root_path, "tests/data/eyebrow_tests/raw_generation_experiment")

os.makedirs(output_dir, exist_ok=True)

UNIFIED_PROMPT_TEMPLATE = "a photo of {celeb} style eyebrows on a face, highly detailed, realistic skin texture, natural skin pores"
UNIFIED_NEGATIVE_PROMPT = "low quality, distorted, blurry, messy, ugly, asymmetric eyebrows, double eyebrows, painted, drawing, illustration, cartoon, fake, 3d render, smooth skin, blurry, plastic, purple patches, colorful noise, burnt, high contrast, hard edges, dirty skin"
STABLE_CN_SCALE = 0

comparison_cases = [
    { "celeb": "고윤정", "display_name": "Go Youn Jung" },
    { "celeb": "신세경", "display_name": "Shin Se Kyung" },
    { "celeb": "홍수주", "display_name": "Hong Su Zu" }
]

class DiffusionBackbone:
    def __init__(self, model_id="runwayml/stable-diffusion-v1-5", dtype=torch.float32):
        self.model_id = model_id
        self.dtype = dtype
    def load_modules(self):
        text_encoder = CLIPTextModel.from_pretrained(self.model_id, subfolder="text_encoder", torch_dtype=self.dtype)
        vae = AutoencoderKL.from_pretrained(self.model_id, subfolder="vae", torch_dtype=self.dtype)
        unet = UNet2DConditionModel.from_pretrained(self.model_id, subfolder="unet", torch_dtype=self.dtype)
        return text_encoder, vae, unet

#======= Device Setup
if torch.cuda.is_available():
    device = "cuda"; dtype = torch.float16
elif torch.backends.mps.is_available():
    device = "mps"; dtype = torch.float32
else:
    device = "cpu"; dtype = torch.float32

def get_canny_guide(image_np):
    img = cv2.Canny(image_np, 100, 200)
    img = img[:, :, None]
    img = np.concatenate([img, img, img], axis=2)
    return Image.fromarray(img)

def color_transfer(src, ref, mask):
    bg_mask = (mask == 0)
    if not np.any(bg_mask): return src
    src_lab = cv2.cvtColor(src, cv2.COLOR_BGR2LAB).astype(np.float32)
    ref_lab = cv2.cvtColor(ref, cv2.COLOR_BGR2LAB).astype(np.float32)
    for i in range(3):
        src_channel = src_lab[:, :, i]
        ref_channel = ref_lab[:, :, i]
        mean_src, std_src = src_channel[bg_mask].mean(), src_channel[bg_mask].std()
        mean_ref, std_ref = ref_channel[bg_mask].mean(), ref_channel[bg_mask].std()
        if std_src > 1e-5:
            src_lab[:, :, i] = (src_channel - mean_src) * (std_ref / std_src) + mean_ref
        else:
            src_lab[:, :, i] = src_channel - mean_src + mean_ref
    return cv2.cvtColor(np.clip(src_lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)

def load_pipeline():
    print(f"Loading base pipeline and loading V4 LoRA checkpoint...")
    backbone = DiffusionBackbone(model_id=base_model_path, dtype=dtype)
    text_encoder, vae, unet = backbone.load_modules()
    
    pipe = StableDiffusionInpaintPipeline.from_pretrained(
        base_model_path, text_encoder=text_encoder, vae=vae, unet=unet,
        torch_dtype=dtype, low_cpu_mem_usage=True, safety_checker=None
    )
    
    from peft import PeftModel
    pipe.unet = PeftModel.from_pretrained(pipe.unet, os.path.join(v4_lora_path, "unet"), adapter_name="unified_v4")
    pipe.text_encoder = PeftModel.from_pretrained(pipe.text_encoder, os.path.join(v4_lora_path, "text_encoder"), adapter_name="unified_v4")
    print(f"✅ Loaded LoRA V4 checkpoint.")
    
    pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
    if device != "cuda":
        pipe.to(device); pipe.enable_attention_slicing(); pipe.enable_vae_slicing()
    else:
        pipe.enable_model_cpu_offload()
    return pipe

def main():
    lora_scale = 1.15
    strength = 0.60
    
    all_imgs = sorted([f for f in os.listdir(input_images_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
    # Run on 10 images as requested
    test_imgs = all_imgs[:10]
    print(f"Starting Raw Generation Experiment on {len(test_imgs)} test images.")
    
    pipe = load_pipeline()
    pipe.set_adapters(["unified_v4"], adapter_weights=[lora_scale])
    
    for idx, img_file in enumerate(test_imgs):
        image_path = os.path.join(input_images_dir, img_file)
        img_basename = img_file.split('.')[0]
        print(f"\n[{idx+1}/{len(test_imgs)}] Processing image: {img_file}")
        
        original_bgr = cv2.imread(image_path)
        if original_bgr is None:
            print(f"Failed to read image: {image_path}")
            continue
        
        # 1. Mask Generation on original face
        raw_mask_base = generate_bisenet_face_parts_mask(original_bgr, parts=["eyebrows"])
        raw_mask_base = dilate_mask(raw_mask_base, pixels=15)
        raw_mask_base = smooth_mask(raw_mask_base)
        
        # 2. Crop to 512x512
        crop_info = get_actor_face_crop_info(raw_mask_base, original_bgr.shape, padding_ratio=4.0)
        image_512 = apply_crop(original_bgr, crop_info, target_size=512)
        mask_512_binary = apply_crop(raw_mask_base, crop_info, target_size=512)
        
        # 3. Telea Fill (Erase Eyebrows)
        textured_fill = cv2.inpaint(image_512, mask_512_binary, 3, cv2.INPAINT_TELEA)
        mask_3ch_smooth = np.repeat(smooth_mask(mask_512_binary)[:, :, np.newaxis], 3, axis=2).astype(np.float32) / 255.0
        masked_image_512 = (image_512 * (1.0 - mask_3ch_smooth) + textured_fill * mask_3ch_smooth).astype(np.uint8)
        
        image_pil = Image.fromarray(cv2.cvtColor(masked_image_512, cv2.COLOR_BGR2RGB))
        pipe_mask_pil = Image.new("RGB", (512, 512), "white")
        control_image_pil = get_canny_guide(image_512)
        
        # Grid preparations
        preview_orig = cv2.resize(cv2.cvtColor(image_512, cv2.COLOR_BGR2RGB), (512, 512))
        cv2.putText(preview_orig, "Original", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
        
        preview_inpainted = cv2.resize(cv2.cvtColor(masked_image_512, cv2.COLOR_BGR2RGB), (512, 512))
        cv2.putText(preview_inpainted, "Inpainted (Input)", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
        
        grid_cols = [preview_orig, preview_inpainted]
        
        # 4. Generate each celeb style
        for case in comparison_cases:
            celeb = case["celeb"]
            display_name = case["display_name"]
            current_prompt = UNIFIED_PROMPT_TEMPLATE.format(celeb=celeb)
            
            print(f"  - Generating {display_name}...")
            generator = torch.Generator(device).manual_seed(42)
            
            output_pil = pipe(
                prompt=current_prompt, negative_prompt=UNIFIED_NEGATIVE_PROMPT,
                image=image_pil, mask_image=pipe_mask_pil, control_image=control_image_pil,
                controlnet_conditioning_scale=STABLE_CN_SCALE, num_inference_steps=40,
                guidance_scale=6.0, strength=strength, generator=generator
            ).images[0]
            
            # Post-processing
            result_np_512 = np.array(output_pil)
            result_bgr_512 = cv2.cvtColor(result_np_512, cv2.COLOR_RGB2BGR)
            
            # Apply color transfer correction to SD output
            corrected_bgr_512 = color_transfer(result_bgr_512, image_512, mask_512_binary)
            
            # Restore and blend
            full_result_np = restore_crop(corrected_bgr_512, crop_info, original_bgr.shape)
            mask_float = smooth_mask(raw_mask_base).astype(np.float32) / 255.0
            mask_3d = np.repeat(mask_float[:, :, np.newaxis], 3, axis=2)
            final_result_bgr = (original_bgr.astype(np.float32) * (1 - mask_3d) + full_result_np.astype(np.float32) * mask_3d).astype(np.uint8)
            
            # Apply crop to final result to get blended face view
            blended_cropped = apply_crop(final_result_bgr, crop_info, target_size=512)
            
            # Visualizations for grid
            # Raw generated face with color correction (what SD generated inside the crop)
            preview_raw = cv2.cvtColor(corrected_bgr_512, cv2.COLOR_BGR2RGB)
            cv2.putText(preview_raw, f"{display_name} (Raw SD)", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 200, 0), 2)
            
            # Blended face crop (how it actually looks when pasted back using original mask)
            preview_blended = cv2.cvtColor(blended_cropped, cv2.COLOR_BGR2RGB)
            cv2.putText(preview_blended, f"{display_name} (Blended)", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
            
            grid_cols.extend([preview_raw, preview_blended])
            
        # Combine column panels into a single wide image row
        grid_row = np.hstack(grid_cols)
        grid_path = os.path.join(output_dir, f"grid_{img_basename}.png")
        Image.fromarray(grid_row).save(grid_path)
        print(f"  - Saved Grid row to: {grid_path}")
        
    print("\nExperiment completed successfully! Output directory:", output_dir)

if __name__ == "__main__":
    main()
