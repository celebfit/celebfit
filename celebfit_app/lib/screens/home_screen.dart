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
    await context.read<AppState>().uploadImageWithScan(bytes: bytes, path: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Stack(
      children: [
        Column(
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
                    _PhotoFrame(
                      imageBytes: state.uploadedImageBytes,
                      isScanning: state.isScanning,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: '사진 업로드',
                      icon: Icons.upload_rounded,
                      onPressed: state.isScanning
                          ? null
                          : () => _pickImage(context, ImageSource.gallery),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: state.isScanning
                                ? null
                                : () => _pickImage(context, ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('카메라로 촬영'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: state.isScanning
                                ? null
                                : () => _pickImage(context, ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('갤러리에서 선택'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
        ),
        if (state.isScanning)
          const Positioned.fill(
            child: _ScanOverlay(),
          ),
      ],
    );
  }
}

class _PhotoFrame extends StatefulWidget {
  const _PhotoFrame({this.imageBytes, this.isScanning = false});
  final Uint8List? imageBytes;
  final bool isScanning;

  @override
  State<_PhotoFrame> createState() => _PhotoFrameState();
}

class _PhotoFrameState extends State<_PhotoFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didUpdateWidget(_PhotoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _scanController.repeat();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _scanController.stop();
      _scanController.reset();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: AppColors.primarySoft,
              child: widget.imageBytes != null
                  ? Image.memory(widget.imageBytes!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('정면 셀카를 업로드해주세요', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
            ),
            if (widget.isScanning)
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ScanLinePainter(progress: _scanController.value),
                    child: Container(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 20),
                      child: const Text(
                        'AI 얼굴 스캔 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.95)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 60), glowPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            SizedBox(height: 14),
            Text('사진 분석 준비 중', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('잠시 후 AI 분석 화면으로 이동합니다', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
