# Conditional Image Generation with BrushNet & BiSeNet

이 프로젝트는 BrushNet(Inpainting)과 BiSeNet(Face Parsing)을 결합하여, 이미지의 특정 얼굴 부위(눈썹, 코, 입술 등)를 자연스럽게 수정(Inpainting)하는 파이프라인입니다. 기존 MediaPipe 기반 방식의 한계를 극복하기 위해 BiSeNet을 사용하여 보다 정교하고 정확한 얼굴 부위 분할(Masking)을 수행합니다.

## 🛠 설치 방법 (Installation)

1. **가상환경 생성 및 활성화** (권장):
```bash
python -m venv .venv
source .venv/bin/activate
```

2. **의존성 패키지 설치**:
루트 디렉토리에 있는 `requirements.txt`를 사용하여 필요한 패키지들을 설치합니다.
```bash
pip install -r requirements.txt
```

> **Mac (Apple Silicon) 사용자 참고:**
> `pipeline/main.py`는 기기의 하드웨어를 감지하여 가능한 경우 MPS (Metal Performance Shaders)를 자동으로 사용하도록 설정되어 있습니다.

---

## 📥 모델 가중치 다운로드 (Weights Download)

이 파이프라인이 정상적으로 작동하려면 크게 세 종류의 가중치/체크포인트가 필요합니다. 아래의 경로 구조에 맞게 파일들을 배치해 주세요.

### 1. BiSeNet 가중치 (Face Parsing용)
ONNX 기반의 얼굴 분할 모델 가중치입니다. 제공된 쉘 스크립트를 통해 자동으로 다운로드할 수 있습니다.
```bash
cd masking_bisenet/face-parsing
chmod +x download.sh
./download.sh
cd ../..
```
- **결과 확인:** 다운로드가 완료되면 `masking_bisenet/face-parsing/weights/` 폴더 내에 `resnet18.onnx`와 `resnet34.onnx` 파일이 존재해야 합니다.

### 2. BrushNet 및 SD 1.5 가중치
메인 Inpainting을 수행하는 확산 모델(Diffusion Model) 체크포인트들입니다. 프로젝트 루트의 `data/ckpt/` 폴더 안에 배치해야 합니다.

*   **Base Model (Stable Diffusion 1.5)**: 
    - HuggingFace의 `runwayml/stable-diffusion-v1-5`를 기본적으로 사용합니다. (코드 실행 시 캐시 폴더로 자동 다운로드됩니다.)
    - *Tip: 네트워크 접속 오류가 발생할 경우 환경변수를 설정하여 미러 사이트를 활용하세요.* (`export HF_ENDPOINT=https://hf-mirror.com`)
*   **BrushNet Checkpoint (`brushnetx`)**:
    1. HuggingFace에서 BrushNet 가중치를 직접 다운로드해야 합니다. [TencentARC/BrushNet](https://huggingface.co/TencentARC/BrushNet/tree/main) 저장소로 이동합니다.
    2. `segmentation_mask_brushnet_ckpt` 폴더의 내용물(특히 `diffusion_pytorch_model.safetensors`와 `config.json`)을 모두 다운로드합니다.
    3. 다운로드한 파일들을 `data/ckpt/brushnetx/` 폴더를 생성한 뒤 그 안에 저장합니다.

### 3. 테스트 데이터
변형할 원본 얼굴 이미지는 `data/raw_face_data/` 폴더에 배치하세요.
- (예시) `data/raw_face_data/seed1056395.png`

---

## 🚀 사용법 (Usage)

`pipeline/main.py` 파일 내의 경로 및 설정을 자신의 환경에 맞게 수정한 후 아래 명령어를 실행합니다.

```bash
python pipeline/main.py
```

### 주요 커스텀 설정 (`pipeline/main.py` 내부)
- **`prompt`**: 수정할 부위와 전체적인 화풍에 대한 매우 구체적인 설명입니다.
  - *Tip: 고보전(High-fidelity) 결과물을 원한다면 단순히 눈썹만 묘사하지 말고, 아래와 같이 전체적인 사진 품질과 피부 질감을 함께 묘사하는 것이 매우 중요합니다.*
  - `RAW photo, a close up portrait of a face, highly detailed, natural skin texture, realistic lighting, 8k uhd, dslr, soft lighting, high quality, film grain, [원하는 눈썹/코 등의 설명]`
- **`target_parts`**: 마스킹하여 수정할 얼굴 부위의 리스트입니다. (예: `["lips", "nose", "eyebrows", "eyes"]`)

### 결과 확인
코드가 성공적으로 실행되면 루트 경로의 `pipeline/` 폴더 안에 `result_face.png` 파일이 생성됩니다.
이 이미지는 다음 4가지 과정을 한눈에 비교할 수 있도록 합쳐진 결과물입니다:
1. **Original**: 원본 이미지
2. **Mask**: BiSeNet이 추출한 마스크 영역 (흰색이 수정될 영역)
3. **Raw Gen**: BrushNet 파이프라인에서 1차적으로 렌더링 된 이미지 (배경 포함)
4. **Result**: 최종적으로 원본 이미지의 배경과 생성된 얼굴 부위를 경계선 없이 부드럽게(Gaussian Blur) 융합시킨 결과물
