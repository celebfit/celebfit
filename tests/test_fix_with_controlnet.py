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
from diffusers import StableDiffusionControlNetInpaintPipeline, ControlNetModel, UniPCMultistepScheduler, UNet2DConditionModel, AutoencoderKL
from transformers import CLIPTextModel
import transformers

if not hasattr(transformers, 'CLIPFeatureExtractor'):
    transformers.CLIPFeatureExtractor = transformers.CLIPImageProcessor

#======= Configuration
base_model_path = "emilianJR/epiCRealism" 
controlnet_id = "lllyasviel/sd-controlnet-canny"
v4_lora_path = os.path.join(root_path, "lora_checkpoint/celeb_eyebrows_all_pro_v4")
input_images_dir = os.path.join(root_path, "data/raw_face_data")
output_dir = os.path.join(root_path, "tests/data/eyebrow_tests/controlnet_verification")

os.makedirs(output_dir, exist_ok=True)

UNIFIED_PROMPT_TEMPLATE = "a photo of {celeb} style eyebrows on a face, highly detailed, realistic skin texture, natural skin pores"
UNIFIED_NEGATIVE_PROMPT = "low quality, distorted, blurry, messy, ugly, asymmetric eyebrows, double eyebrows, painted, drawing, illustration, cartoon, fake, 3d render, smooth skin, blurry, plastic, purple patches, colorful noise, burnt, high contrast, hard edges, dirty skin"

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
    print(f"Loading models with Canny ControlNet...")
    backbone = DiffusionBackbone(model_id=base_model_path, dtype=dtype)
    text_encoder, vae, unet = backbone.load_modules()
    controlnet = ControlNetModel.from_pretrained(controlnet_id, torch_dtype=dtype)
    
    pipe = StableDiffusionControlNetInpaintPipeline.from_pretrained(
        base_model_path, controlnet=controlnet, text_encoder=text_encoder, vae=vae, unet=unet,
        torch_dtype=dtype, low_cpu_mem_usage=True, safety_checker=None
    )
    
    from peft import PeftModel
    pipe.unet = PeftModel.from_pretrained(pipe.unet, os.path.join(v4_lora_path, "unet"), adapter_name="unified_v4")
    pipe.text_encoder = PeftModel.from_pretrained(pipe.text_encoder, os.path.join(v4_lora_path, "text_encoder"), adapter_name="unified_v4")
    pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
    
    if device != "cuda":
        pipe.to(device); pipe.enable_attention_slicing(); pipe.enable_vae_slicing()
    else:
        pipe.enable_model_cpu_offload()
    return pipe

def main():
    test_files = ["seed1000166.png", "seed1000187.png"]
    pipe = load_pipeline()
    pipe.set_adapters(["unified_v4"], adapter_weights=[1.15])
    
    control_scales = [0.0, 0.4, 0.7]
    
    for img_file in test_files:
        image_path = os.path.join(input_images_dir, img_file)
        img_basename = img_file.split('.')[0]
        print(f"\nProcessing image: {img_file}")
        
        original_bgr = cv2.imread(image_path)
        if original_bgr is None: continue
        
        # Mask
        raw_mask_base = generate_bisenet_face_parts_mask(original_bgr, parts=["eyebrows"])
        raw_mask_base = dilate_mask(raw_mask_base, pixels=15)
        raw_mask_base = smooth_mask(raw_mask_base)
        
        crop_info = get_actor_face_crop_info(raw_mask_base, original_bgr.shape, padding_ratio=4.0)
        image_512 = apply_crop(original_bgr, crop_info, target_size=512)
        mask_512_binary = apply_crop(raw_mask_base, crop_info, target_size=512)
        
        # Telea fill on input image to erase eyebrows
        mask_3ch_smooth = np.repeat(smooth_mask(mask_512_binary)[:, :, np.newaxis], 3, axis=2).astype(np.float32) / 255.0
        textured_fill = cv2.inpaint(image_512, mask_512_binary, 3, cv2.INPAINT_TELEA)
        input_telea = (image_512 * (1.0 - mask_3ch_smooth) + textured_fill * mask_3ch_smooth).astype(np.uint8)
        
        image_pil = Image.fromarray(cv2.cvtColor(input_telea, cv2.COLOR_BGR2RGB))
        pipe_mask_pil = Image.new("RGB", (512, 512), "white")
        
        # Canny guide from the ORIGINAL image (holds the original eyebrow shape edges!)
        control_image_pil = get_canny_guide(image_512)
        
        rows = []
        
        for scale in control_scales:
            panels = [cv2.resize(cv2.cvtColor(image_512, cv2.COLOR_BGR2RGB), (256, 256))]
            cv2.putText(panels[0], f"CN Scale: {scale:.1f}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            
            for case in comparison_cases:
                celeb = case["celeb"]
                display_name = case["display_name"]
                current_prompt = UNIFIED_PROMPT_TEMPLATE.format(celeb=celeb)
                
                print(f"  - ControlNet Scale {scale:.1f} | Celebrity {display_name}...")
                generator = torch.Generator(device).manual_seed(42)
                
                output_pil = pipe(
                    prompt=current_prompt, negative_prompt=UNIFIED_NEGATIVE_PROMPT,
                    image=image_pil, mask_image=pipe_mask_pil, control_image=control_image_pil,
                    controlnet_conditioning_scale=scale, num_inference_steps=40,
                    guidance_scale=6.0, strength=0.60, generator=generator
                ).images[0]
                
                # Blend
                result_np_512 = np.array(output_pil)
                result_bgr_512 = cv2.cvtColor(result_np_512, cv2.COLOR_RGB2BGR)
                corrected_bgr_512 = color_transfer(result_bgr_512, image_512, mask_512_binary)
                
                full_result_np = restore_crop(corrected_bgr_512, crop_info, original_bgr.shape)
                mask_float = smooth_mask(raw_mask_base).astype(np.float32) / 255.0
                mask_3d = np.repeat(mask_float[:, :, np.newaxis], 3, axis=2)
                final_result_bgr = (original_bgr.astype(np.float32) * (1 - mask_3d) + full_result_np.astype(np.float32) * mask_3d).astype(np.uint8)
                
                blended_cropped = apply_crop(final_result_bgr, crop_info, target_size=256)
                preview_blended = cv2.cvtColor(blended_cropped, cv2.COLOR_BGR2RGB)
                cv2.putText(preview_blended, f"{display_name}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                panels.append(preview_blended)
                
            rows.append(np.hstack(panels))
            
        grid = np.vstack(rows)
        grid_path = os.path.join(output_dir, f"cn_verification_{img_basename}.png")
        Image.fromarray(grid).save(grid_path)
        print(f"Saved ControlNet verification grid to: {grid_path}")

if __name__ == "__main__":
    main()
