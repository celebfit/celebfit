import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'B',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('celebfit', style: AppTheme.brandLogo()),
      ],
    );
  }
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title,
    this.showLogo = false,
    this.showBack = false,
    this.showBell = false,
    this.showShare = false,
    this.onBack,
  });

  final String? title;
  final bool showLogo;
  final bool showBack;
  final bool showBell;
  final bool showShare;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              )
            else if (showLogo)
              const BrandLogo()
            else
              const SizedBox(width: 36),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              )
            else
              const Spacer(),
            if (showBell)
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined, size: 22),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              )
            else if (showShare)
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.share_outlined, size: 22),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              )
            else
              const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
    if (expanded) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.showDensityBar = false,
    this.showDensityGrid = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool showDensityBar;
  final bool showDensityGrid;
  final bool compact;

  static const _densityColors = [
    Color(0xFFF5F0EA),
    Color(0xFFE8DDD0),
    Color(0xFFD4C4B0),
    Color(0xFFB8A088),
    Color(0xFF9A8570),
    Color(0xFF7A6550),
    Color(0xFF5C4A3A),
    Color(0xFF3E3228),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 11 : 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (value.isNotEmpty) ...[
            SizedBox(height: compact ? 1 : 2),
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (showDensityBar) ...[
            SizedBox(height: compact ? 4 : 6),
            Container(
              height: compact ? 7 : 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF0EBE4),
                    Color(0xFFD4C4B0),
                    Color(0xFF9A8570),
                    Color(0xFF5C4A3A),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '연함',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '진함',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
          if (showDensityGrid) ...[
            SizedBox(height: compact ? 3 : 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: 24,
              itemBuilder: (context, index) {
                final col = index % 8;
                final row = index ~/ 8;
                final tone = ((col / 7) * 0.55 + (row / 2) * 0.35).clamp(0.0, 1.0);
                final colorIndex = (tone * (_densityColors.length - 1)).round();
                return Container(
                  decoration: BoxDecoration(
                    color: _densityColors[colorIndex],
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '연함',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '진함',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ProgressScoreRow extends StatelessWidget {
  const ProgressScoreRow({super.key, required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                backgroundColor: AppColors.primaryLight,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((filter) {
            final isSelected = filter == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class EmptyStatePlaceholder extends StatelessWidget {
  const EmptyStatePlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
      ),
    );
  }
}
