import os
import sys
import numpy as np
import cv2

# Ensure face-parsing can be imported
current_dir = os.path.dirname(os.path.abspath(__file__))
face_parsing_dir = os.path.join(current_dir, 'face-parsing')

# BiSeNet 19 Classes
PART_TO_CLASSES = {
    "lips": [11, 12, 13],    # mouth, u_lip, l_lip
    "nose": [10],
    "left_eyebrow": [2],
    "right_eyebrow": [3],
    "eyebrows": [2, 3],
    "eyes": [4, 5],
    "hair": [17],
    "skin": [1],
}

_onnx_session = None

def get_onnx_session():
    global _onnx_session
    if _onnx_session is None:
        import onnxruntime as ort
        
        weight_path = os.path.join(face_parsing_dir, 'weights', 'resnet18.onnx')
        if not os.path.exists(weight_path):
            print(f"BiSeNet ONNX weight file not found: {weight_path}")
            print(f"Please run download.sh in the {face_parsing_dir} directory to download the weights.")
            raise FileNotFoundError(f"ONNX weight not found at {weight_path}.")
            
        providers = (
            ['CUDAExecutionProvider', 'CPUExecutionProvider']
            if ort.get_device() == 'GPU'
            else ['CPUExecutionProvider']
        )
        _onnx_session = ort.InferenceSession(weight_path, providers=providers)
    return _onnx_session

def generate_bisenet_face_parts_mask(img_bgr, parts):
    session = get_onnx_session()
    
    # Record original dimensions
    original_size = (img_bgr.shape[1], img_bgr.shape[0])  # (W, H)
    
    # Preprocessing
    input_size = (512, 512)
    input_mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    input_std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    img_resized = cv2.resize(img_rgb, input_size, interpolation=cv2.INTER_LINEAR)
    
    img_norm = img_resized.astype(np.float32) / 255.0
    img_norm = (img_norm - input_mean) / input_std
    
    img_transposed = np.transpose(img_norm, (2, 0, 1))  # HWC -> CHW
    img_batch = np.expand_dims(img_transposed, axis=0).astype(np.float32)  # CHW -> BCHW
    
    # Inference
    input_name = session.get_inputs()[0].name
    output_names = [output.name for output in session.get_outputs()]
    
    outputs = session.run(output_names, {input_name: img_batch})
    
    # Post-processing
    predicted_mask = outputs[0].squeeze(0).argmax(0).astype(np.uint8)
    restored_mask = cv2.resize(predicted_mask, original_size, interpolation=cv2.INTER_NEAREST)
    
    # Extract specific facial parts
    final_mask = np.zeros_like(restored_mask, dtype=np.uint8)
    for part in parts:
        part = part.lower()
        if part in PART_TO_CLASSES:
            for cls_idx in PART_TO_CLASSES[part]:
                final_mask[restored_mask == cls_idx] = 255
                
    return final_mask
