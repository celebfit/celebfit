import os
import sys
import torch
import random
import numpy as np
import cv2
import matplotlib.pyplot as plt
from PIL import Image

# Setup paths
root_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, root_path)
sys.path.insert(0, os.path.join(root_path, "brushnet/src"))

from diffusers import StableDiffusionInpaintPipeline, UniPCMultistepScheduler, UNet2DConditionModel, AutoencoderKL
from transformers import CLIPTextModel
from peft import PeftModel
from masking_bisenet.generate_mask_bisenet import generate_bisenet_face_parts_mask
from util.dilate_mask import dilate_mask
from util.smooth_mask import smooth_mask
from util.crop_face import get_crop_info, apply_crop

# Configuration
base_model_path = "emilianJR/epiCRealism"
unified_lora_path = os.path.join(root_path, "data/ckpt/celeb_eyebrows_all_pro_v2")
input_images_dir = os.path.join(root_path, "data/raw_face_data")
output_dir = os.path.join(root_path, "tests/data/eyebrow_visualize")
os.makedirs(output_dir, exist_ok=True)

device = "mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float32

# Inpaint settings (using reverted parameters for optimal visual quality)
STABLE_STRENGTH = 0.50
STABLE_LORA_SCALE = 0.90
UNIFIED_NEGATIVE_PROMPT = "low quality, distorted, blurry, messy, ugly, asymmetric eyebrows, double eyebrows"

class EyebrowFeatureHook:
    """
    Hook to capture features from the UNet mid-block attention layer
    at all timesteps, focusing only on the masked eyebrow region.
    """
    def __init__(self, actor_name, mask_512_binary, total_steps):
        self.actor_name = actor_name
        self.mask_512_binary = mask_512_binary
        self.total_steps = total_steps
        self.step_counter = 0
        self.features_extracted = []  # List of tuples: (step, feature_vector)

    def __call__(self, module, input, output):
        # output is typically a tensor of shape [batch_size, seq_len, channels] or [batch_size, channels, height, width]
        tensor = output[0] if isinstance(output, tuple) else output
        
        # Separate CFG batch: index 1 is the positive/conditional prompt, index 0 is negative/unconditional
        idx = 1 if tensor.shape[0] > 1 else 0
        val = tensor[idx].detach().cpu().float().numpy() # [Channels, Height, Width] or [Seq_len, Channels]
        
        # We only log features at the final steps (last 3 steps) where the style is fully formed
        # Dynamic check based on total steps
        if self.step_counter >= max(0, self.total_steps - 3):
            # Normalize shape to [Channels, Height, Width]
            if len(val.shape) == 3: # [C, H, W]
                c, h, w = val.shape
            elif len(val.shape) == 2: # [Seq_len, C]
                seq_len, c = val.shape
                import math
                h = w = int(math.sqrt(seq_len))
                val = val.reshape(h, w, c).transpose(2, 0, 1) # [C, H, W]
            else:
                self.step_counter += 1
                return
            
            # Downsample eyebrow mask to match feature map resolution (H x W)
            mask_resized = cv2.resize(self.mask_512_binary, (w, h), interpolation=cv2.INTER_NEAREST)
            mask_resized = mask_resized.astype(np.float32) / 255.0
            
            # Weighted average over the eyebrow mask area
            mask_sum = mask_resized.sum()
            if mask_sum > 0:
                masked_avg = (val * mask_resized).sum(axis=(1, 2)) / mask_sum
            else:
                masked_avg = val.mean(axis=(1, 2))
                
            self.features_extracted.append((self.step_counter, masked_avg))
        self.step_counter += 1

def load_pipeline():
    print(f"Loading pipeline on {device}...")
    text_encoder = CLIPTextModel.from_pretrained(base_model_path, subfolder="text_encoder", torch_dtype=dtype)
    vae = AutoencoderKL.from_pretrained(base_model_path, subfolder="vae", torch_dtype=dtype)
    unet = UNet2DConditionModel.from_pretrained(base_model_path, subfolder="unet", torch_dtype=dtype)
    
    pipe = StableDiffusionInpaintPipeline.from_pretrained(
        base_model_path, text_encoder=text_encoder, vae=vae, unet=unet,
        torch_dtype=dtype, low_cpu_mem_usage=True, safety_checker=None
    )
    
    # Load Unified LoRA if exists
    if os.path.exists(os.path.join(unified_lora_path, "unet")):
        pipe.unet = PeftModel.from_pretrained(pipe.unet, os.path.join(unified_lora_path, "unet"), adapter_name="all_celebs")
        pipe.text_encoder = PeftModel.from_pretrained(pipe.text_encoder, os.path.join(unified_lora_path, "text_encoder"), adapter_name="all_celebs")
        print("✅ Loaded Unified LoRA weights!")
        pipe.enable_lora()
        pipe.set_adapters(["all_celebs"], adapter_weights=[STABLE_LORA_SCALE])
    else:
        print("WARNING: Unified LoRA weights not found! Running base model instead.")
        
    pipe.scheduler = UniPCMultistepScheduler.from_config(pipe.scheduler.config)
    pipe.to(device)
    return pipe

def plot_3d_features(coords, labels, title, filename, algo_name="PCA"):
    from sklearn.metrics import silhouette_score
    
    # Map labels to English for clean legend rendering
    eng_label_map = {
        "고윤정": "Go Yoon-jung",
        "신세경": "Shin Se-kyung",
        "홍수주": "Hong Su-zu"
    }
    mapped_labels = np.array([eng_label_map.get(l, l) for l in labels])
    unique_labels = sorted(list(set(mapped_labels)))
    colors = ['#FF4B4B', '#00C0A3', '#3B82F6']
    color_map = {name: colors[i] for i, name in enumerate(unique_labels)}
    
    score = silhouette_score(coords, mapped_labels)
    print(f"  - {algo_name} Silhouette Score for UNet Image Features: {score:.4f}")
    
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    
    for label_name in unique_labels:
        mask = (mapped_labels == label_name)
        ax.scatter(
            coords[mask, 0], coords[mask, 1], coords[mask, 2],
            c=color_map[label_name], label=label_name,
            alpha=0.8, edgecolors='none', s=60
        )
        
    ax.set_title(f"3D UNet Image Feature Space ({algo_name})\n(Silhouette Score: {score:.4f})", fontsize=14, fontweight='bold')
    ax.set_xlabel("Dim 1", fontsize=10)
    ax.set_ylabel("Dim 2", fontsize=10)
    ax.set_zlabel("Dim 3", fontsize=10)
    ax.grid(True, linestyle='--', alpha=0.5)
    ax.legend(loc='upper right', framealpha=0.9)
    
    # Styling
    ax.xaxis.pane.fill = False
    ax.yaxis.pane.fill = False
    ax.zaxis.pane.fill = False
    ax.xaxis.pane.set_edgecolor('w')
    ax.yaxis.pane.set_edgecolor('w')
    ax.zaxis.pane.set_edgecolor('w')
    
    plt.tight_layout()
    save_path = os.path.join(output_dir, filename)
    plt.savefig(save_path, dpi=200, bbox_inches='tight')
    plt.close()
    print(f"Saved {algo_name} visualization to: {save_path}")

def fill_skin_color(image_bgr, mask_binary):
    """
    Fills the masked region (eyebrows) with skin color calculated from the surrounding border.
    This wipes out the eyebrow shape, forcing the diffusion model to generate shapes purely from prompt/LoRA.
    """
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
    dilated = cv2.dilate(mask_binary, kernel, iterations=1)
    border_mask = cv2.subtract(dilated, mask_binary)
    
    skin_pixels = image_bgr[border_mask > 0]
    if len(skin_pixels) > 0:
        median_color = np.median(skin_pixels, axis=0).astype(np.uint8)
    else:
        median_color = np.array([200, 200, 220], dtype=np.uint8) # default peach skin
        
    filled_img = image_bgr.copy()
    filled_img[mask_binary > 0] = median_color
    
    mask_blurred = cv2.GaussianBlur(mask_binary, (21, 21), 0).astype(np.float32) / 255.0
    mask_blurred_3d = np.repeat(mask_blurred[:, :, np.newaxis], 3, axis=2)
    
    blended = (image_bgr.astype(np.float32) * (1.0 - mask_blurred_3d) + 
               filled_img.astype(np.float32) * mask_blurred_3d).astype(np.uint8)
    return blended

def main():
    pipe = load_pipeline()
    
    all_imgs = sorted([f for f in os.listdir(input_images_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
    test_imgs = all_imgs[:10] # Use 10 images for more data points
    
    print(f"\nStep 1: Running inpaint loop to capture UNet features for {len(test_imgs)} images...")
    
    feature_vectors = []
    labels = []
    
    celebs = ["고윤정", "신세경", "홍수주"]
    
    for img_file in test_imgs:
        img_path = os.path.join(input_images_dir, img_file)
        original_bgr = cv2.imread(img_path)
        if original_bgr is None: continue
        
        # Generate Mask
        raw_mask_base = generate_bisenet_face_parts_mask(original_bgr, parts=["eyebrows"])
        # Dilate mask by 15px (matching reverted settings)
        raw_mask_base = dilate_mask(raw_mask_base, pixels=15)
        raw_mask_base = smooth_mask(raw_mask_base)
        
        # Crop
        crop_info = get_crop_info(raw_mask_base, original_bgr.shape, target_size=512)
        image_512 = apply_crop(original_bgr, crop_info, target_size=512)
        mask_512_binary = apply_crop(raw_mask_base, crop_info, target_size=512)
        
        # Telea Fill for base (matching reverted settings to maintain natural texture)
        textured_fill = cv2.inpaint(image_512, mask_512_binary, 3, cv2.INPAINT_TELEA)
        mask_3ch_smooth = np.repeat(smooth_mask(mask_512_binary)[:, :, np.newaxis], 3, axis=2).astype(np.float32) / 255.0
        masked_image_512 = (image_512 * (1.0 - mask_3ch_smooth) + textured_fill * mask_3ch_smooth).astype(np.uint8)
        
        image_pil = Image.fromarray(cv2.cvtColor(masked_image_512, cv2.COLOR_BGR2RGB))
        # Use white mask for full-face generation (matching reverted settings for natural blending)
        pipe_mask_pil = Image.new("RGB", (512, 512), "white")
        
        celeb_shapes = {
            "고윤정": "thick flat eyebrows, straight style",
            "신세경": "thin soft arched eyebrows, delicate curved style",
            "홍수주": "thick bushy wild eyebrows, dense hair texture"
        }
        
        for celeb in celebs:
            print(f"  - Extracting features for: {img_file} | actor: {celeb}...")
            shape_keyword = celeb_shapes[celeb]
            current_prompt = f"a photo of {celeb} style eyebrows, {shape_keyword}, highly detailed, natural hair texture, masterpiece, 8k uhd"
            
            # Setup Hook on UNet up-block attention (capture only the last 3 steps)
            total_steps = int(15 * STABLE_STRENGTH)
            hook = EyebrowFeatureHook(celeb, mask_512_binary, total_steps)
            hook_handle = pipe.unet.up_blocks[1].attentions[1].register_forward_hook(hook)
            
            generator = torch.Generator(device).manual_seed(42)
            
            # Run inference
            with torch.no_grad():
                _ = pipe(
                    prompt=current_prompt, negative_prompt=UNIFIED_NEGATIVE_PROMPT,
                    image=image_pil, mask_image=pipe_mask_pil,
                    num_inference_steps=15, guidance_scale=6.0,
                    strength=STABLE_STRENGTH, generator=generator
                )
                
            # Remove Hook
            hook_handle.remove()
            
            # Retrieve features
            for step, feat in hook.features_extracted:
                feature_vectors.append(feat)
                # Label is actor name
                labels.append(celeb)
                
    feature_vectors = np.array(feature_vectors)
    labels = np.array(labels)
    
    print(f"\nExtracted {len(feature_vectors)} image feature vectors of dimension {feature_vectors.shape[1]}.")
    
    # Dimensionality Reduction
    print("\nStep 2: Performing 3D PCA on UNet features...")
    from sklearn.decomposition import PCA
    pca = PCA(n_components=3, random_state=42)
    unet_pca = pca.fit_transform(feature_vectors)
    plot_3d_features(unet_pca, labels, "UNet Features PCA", "unet_latent_space_pca.png", algo_name="PCA")
    
    print("\nStep 3: Performing 3D t-SNE on UNet features...")
    from sklearn.manifold import TSNE
    tsne = TSNE(n_components=3, perplexity=8, max_iter=1000, random_state=42)
    unet_tsne = tsne.fit_transform(feature_vectors)
    plot_3d_features(unet_tsne, labels, "UNet Features t-SNE", "unet_latent_space_tsne.png", algo_name="t-SNE")
    
    print(f"\n🎉 UNet feature visualization finished successfully! Output saved in: {output_dir}/")

if __name__ == "__main__":
    main()
