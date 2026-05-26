import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    context.read<AppState>().setUploadedImage(bytes: bytes, path: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        const AppHeader(showLogo: true, showBell: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 얼굴에 맞는\n눈썹 찾기', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                _PhotoFrame(imageBytes: state.uploadedImageBytes),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: '사진 업로드',
                  icon: Icons.upload_rounded,
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(context, ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('카메라로 촬영'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(context, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('갤러리에서 선택'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text('추후 확장 예정', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _FutureModule(icon: Icons.visibility_outlined, label: '눈'),
                          SizedBox(width: 28),
                          _FutureModule(icon: Icons.face_outlined, label: '코'),
                          SizedBox(width: 28),
                          _FutureModule(icon: Icons.sentiment_satisfied_alt_outlined, label: '입'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Safe data protection', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({this.imageBytes});
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          color: AppColors.primarySoft,
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text('정면 셀카를 업로드해주세요', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FutureModule extends StatelessWidget {
  const _FutureModule({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
