import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/app_models.dart';
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
    required this.onApply,
    this.subtitle,
    this.description,
    this.previewAsset,
    this.imageBytes,
    this.enabled = true,
    this.isLoading = false,
    this.isRecommended = false,
    this.compact = false,
  });

  final String name;
  final String? subtitle;
  final String? description;
  final String? previewAsset;
  final Uint8List? imageBytes;
  final VoidCallback onApply;
  final bool enabled;
  final bool isLoading;
  final bool isRecommended;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard();
    }
    return _buildListCard();
  }

  Widget _buildPreviewImage({Alignment alignment = Alignment.topCenter, double scale = 1.0}) {
    Widget image;
    if (previewAsset != null) {
      if (previewAsset!.toLowerCase().endsWith('.svg')) {
        image = SvgPicture.asset(
          previewAsset!,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        image = Image.asset(
          previewAsset!,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          width: double.infinity,
          height: double.infinity,
        );
      }
    } else if (imageBytes != null) {
      image = Image.memory(imageBytes!, fit: BoxFit.cover, alignment: alignment);
    } else {
      return Container(color: AppColors.primarySoft, child: const _EyebrowPainterWidget());
    }

    if (scale != 1.0) {
      image = Transform.scale(scale: scale, alignment: alignment, child: image);
    }
    return image;
  }

  Widget _buildListCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isRecommended ? AppColors.primary : AppColors.border,
          width: isRecommended ? 1.5 : 1,
        ),
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
            child: SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreviewImage(
                    alignment: const Alignment(0, -0.16),
                  ),
                  if (isRecommended)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '추천',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _ApplyButton(enabled: enabled, isLoading: isLoading, onApply: onApply, compact: true),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: _buildPreviewImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle ?? name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                _ApplyButton(enabled: enabled, isLoading: isLoading, onApply: onApply),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.enabled,
    required this.isLoading,
    required this.onApply,
    this.compact = false,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onApply;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.applyBtnBg : AppColors.chipBg,
      borderRadius: BorderRadius.circular(compact ? 7 : 8),
      child: InkWell(
        onTap: enabled && !isLoading ? onApply : null,
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : Text(
                  enabled ? (compact ? '적용' : '적용하기') : '준비중',
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EyebrowPainterWidget extends StatelessWidget {
  const _EyebrowPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EyebrowPainter());
  }
}

class GenderBanner extends StatelessWidget {
  const GenderBanner({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CelebGender selected;
  final ValueChanged<CelebGender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _GenderTab(
              label: '여자 연예인',
              selected: selected == CelebGender.female,
              onTap: () => onChanged(CelebGender.female),
            ),
          ),
          Expanded(
            child: _GenderTab(
              label: '남자 연예인',
              selected: selected == CelebGender.male,
              onTap: () => onChanged(CelebGender.male),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderTab extends StatelessWidget {
  const _GenderTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
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

class CelebrityMatchCard extends StatelessWidget {
  const CelebrityMatchCard({super.key, required this.match});

  final CelebrityMatch match;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: match.showCrown ? AppColors.primary : AppColors.border,
            width: match.showCrown ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    match.previewAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.high,
                  ),
                  if (match.showCrown)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Text('👑', style: TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.styleLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    match.name,
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${match.percent}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceLandmarkOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    _drawDashedLine(
      canvas,
      Offset(size.width * 0.5, size.height * 0.08),
      Offset(size.width * 0.5, size.height * 0.92),
      line,
    );

    final left = [
      Offset(size.width * 0.14, size.height * 0.36),
      Offset(size.width * 0.24, size.height * 0.33),
      Offset(size.width * 0.34, size.height * 0.32),
      Offset(size.width * 0.44, size.height * 0.34),
    ];
    final right = [
      Offset(size.width * 0.56, size.height * 0.34),
      Offset(size.width * 0.66, size.height * 0.32),
      Offset(size.width * 0.76, size.height * 0.33),
      Offset(size.width * 0.86, size.height * 0.36),
    ];

    for (final brow in [left, right]) {
      final path = Path()..moveTo(brow.first.dx, brow.first.dy);
      for (final p in brow.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      _drawDashedPath(canvas, path, line);
      for (final p in brow) {
        canvas.drawCircle(
          p,
          2.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          p,
          2.5,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    _drawDashedPath(canvas, Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy), paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dash = 4, double gap = 3}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
