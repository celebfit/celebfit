# Conditional Eyebrow Image Generation (SD Inpaint + Celeb LoRA)

이 프로젝트는 **BiSeNet(Face Parsing)** 기반의 정교한 눈썹 마스킹 기술과 **Stable Diffusion Inpainting + LoRA** 파이프라인을 결합하여, 이미지 내의 눈썹을 특정 배우 스타일(고윤정, 신세경, 홍수주)로 자연스럽고 사실적으로 변형 및 생성하는 프로젝트입니다.

> [!IMPORTANT]
> **BrushNet 관련 변경 안내:**
> 기존의 BrushNet 의존성이 완전히 제거되었습니다. **이제 BrushNet의 대용량 체크포인트(brushnetx)를 별도로 다운로드할 필요가 없습니다.**

---

## 🛠 설치 방법 (Installation)

1. **가상환경 생성 및 활성화**:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```

2. **의존성 패키지 설치**:
   ```bash
   pip install -r requirements.txt
   ```

---

## 📥 모델 가중치 및 데이터 설정 (Weights & Data Setup)

### 1. BiSeNet 가중치 (얼굴 분할용)
자동으로 다운로드 스크립트를 실행하여 ONNX 가중치를 받아옵니다.
```bash
cd masking_bisenet/face-parsing
chmod +x download.sh
./download.sh
cd ../..
```
* **결과 확인:** `masking_bisenet/face-parsing/weights/` 폴더 내에 `resnet18.onnx`와 `resnet34.onnx`가 준비되어야 합니다.

### 2. Base Model (기반 확산 모델)
* 기본적으로 초고화질 실사 체크포인트인 **`emilianJR/epiCRealism`**을 사용합니다.
* 코드를 실행할 때 Hugging Face Diffusers를 통해 캐시 디렉토리로 자동 다운로드되므로 수동 다운로드가 필요하지 않습니다.

### 3. LoRA 가중치 저장소
* 직접 훈련을 마치거나 훈련된 LoRA 가중치 폴더들이 `data/ckpt/` 아래에 위치해야 합니다.
  - 통합 LoRA: `data/ckpt/celeb_eyebrows_all_pro_v2/`
  - 개인별 LoRA: `data/ckpt/{배우이름}_eyebrows_pro_v2/`

### 4. 학습 및 테스트 데이터 구조
* **배우 원본 이미지**: `data/actor_raw_data/{배우이름}/001.jpg` ...
* **학습용 눈썹 마스크 및 누끼**: `data/수정본/{배우이름}_mask/`
  - `extracted/`: 흰색 배경의 눈썹 이미지 (`_tight_white_bg.png`)
  - `tight/`: 타이트한 흑백 마스크 이미지 (`_tight_mask.png`)
  - `padded_2px/`: 2px 팽창된 마스크 이미지 (피부 경계면 자연스러운 블렌딩 학습용)

---

## 🚀 전체 개발 & 검증 워크플로우 (Workflow)

프로젝트는 **[학습 ➔ 단일 이미지 테스트 ➔ 비교 그리드 생성 ➔ 3D 특징 분포 분석]** 의 전체 검증 루프를 제공합니다.

### Step 1. LoRA 학습 (Multi-Aspect Data Mixing & Rank 128)
새롭게 개선된 학습 방식은 **Data Mixing**을 적용하여 각 샘플마다 3가지 조합을 학습시킵니다:
1. **Pure Eyebrow**: 흰색 배경의 눈썹 특사 이미지 + Tight 마스크 (눈썹 모류 및 질감 극대화 학습)
2. **Face Context**: 얼굴 원본 이미지 + Tight 마스크 (눈썹의 얼굴 내 정확한 안착 위치 학습)
3. **Edge Blending**: 얼굴 원본 이미지 + 2px 확장 마스크 (피부와 눈썹 경계면의 부드러운 전이 학습)

또한 LoRA 용량을 **`Rank 128 / Alpha 128`**로 확장하여 정교한 형태 표현이 가능합니다.
```bash
python pipeline/train_lora.py
```

### Step 2. 단일 이미지 인페인팅 테스트 (pipeline/main.py)
특정 원본 얼굴 사진의 눈썹 영역을 마스킹하고, 학습된 LoRA를 입혀 자연스럽게 가우시안 블렌딩 처리하여 최종 변형 이미지를 생성합니다.
```bash
python pipeline/main.py
```
* **결과 저장**: `pipeline/result_face.png`에 [원본, 마스크, 결과] 3단 프리뷰로 저장됩니다.
* `TARGET_CELEB` 변수('고윤정', '신세경', '홍수주')를 변경하여 타겟 배우를 지정할 수 있습니다.

### Step 3. 비교 그리드 생성 및 3D 특징 분석 시각화 통합 실행 (tests/test_eyebrows_compare_loras.py)
지정된 얼굴 이미지들에 대해 **고윤정(평조/둥근眉), 신세경(아치형眉), 홍수주(와일드/야생眉)** LoRA를 각각 적용한 그리드 이미지를 생성하는 것과 동시에, UNet Up-block Attention 특징 맵을 낚아채어(Hook) **3D PCA** 및 **3D t-SNE** 특징 공간 투영 그래프를 한 번에 자동 렌더링합니다.
```bash
python tests/test_eyebrows_compare_loras.py
```
* **원타임 최적화**: 두 작업을 하나로 병합하여 Diffusion 생성에 드는 계산 시간과 GPU 소모를 50% 단축했습니다.
* **결과 저장**:
  - **비교 그리드**: `tests/data/eyebrow_tests/grids_compare/` 에 시드별 격자 비교 이미지 저장.
  - **3D 시각화 그래프**: `tests/data/eyebrow_visualize/` 내에 `unet_latent_space_pca.png` 및 `unet_latent_space_tsne.png` 로 투영 결과 저장.

