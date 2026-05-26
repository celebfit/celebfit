import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
    this.aspectRatio = 3 / 4,
  });

  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final double aspectRatio;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _position = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerX = width * _position;

        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _position =
                      (_position + details.delta.dx / width).clamp(0.05, 0.95);
                });
              },
              onTapDown: (details) {
                setState(() {
                  _position = (details.localPosition.dx / width).clamp(0.05, 0.95);
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(widget.afterBytes, fit: BoxFit.cover),
                  ClipRect(
                    clipper: _BeforeClipper(dividerX),
                    child: Image.memory(widget.beforeBytes, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: dividerX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(top: 12, left: 12, child: _Badge(text: 'Before')),
                  const Positioned(top: 12, right: 12, child: _Badge(text: 'After')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BeforeClipper extends CustomClipper<Rect> {
  _BeforeClipper(this.dividerX);
  final double dividerX;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, dividerX, size.height);

  @override
  bool shouldReclip(_BeforeClipper oldClipper) => oldClipper.dividerX != dividerX;
}

class StylePreviewCard extends StatelessWidget {
  const StylePreviewCard({
    super.key,
    required this.name,
    required this.imageBytes,
    required this.onApply,
    this.isLoading = false,
  });

  final String name;
  final Uint8List? imageBytes;
  final VoidCallback onApply;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageBytes != null)
                    Image.memory(imageBytes!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                  else
                    Container(color: AppColors.primarySoft),
                  CustomPaint(painter: _EyebrowPainter()),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Material(
                  color: AppColors.applyBtnBg,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: isLoading ? null : onApply,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Text(
                              '적용하기',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EyebrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5C4033).withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height * 0.42;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 38, cy + 2)
        ..quadraticBezierTo(cx - 18, cy - 6, cx, cy - 2)
        ..quadraticBezierTo(cx + 18, cy - 6, cx + 38, cy + 2),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 38, cy + 12)
        ..quadraticBezierTo(cx - 18, cy + 4, cx, cy + 8)
        ..quadraticBezierTo(cx + 18, cy + 4, cx + 38, cy + 12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FaceLandmarkOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final left = [
      Offset(size.width * 0.22, size.height * 0.37),
      Offset(size.width * 0.30, size.height * 0.35),
      Offset(size.width * 0.38, size.height * 0.34),
      Offset(size.width * 0.46, size.height * 0.36),
    ];
    final right = [
      Offset(size.width * 0.54, size.height * 0.36),
      Offset(size.width * 0.62, size.height * 0.34),
      Offset(size.width * 0.70, size.height * 0.35),
      Offset(size.width * 0.78, size.height * 0.37),
    ];

    for (final brow in [left, right]) {
      final path = Path()..moveTo(brow.first.dx, brow.first.dy);
      for (final p in brow.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
      for (final p in brow) {
        canvas.drawCircle(p, 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
