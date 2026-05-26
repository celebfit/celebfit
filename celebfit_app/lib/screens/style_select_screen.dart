import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/visual_widgets.dart';

class StyleSelectScreen extends StatefulWidget {
  const StyleSelectScreen({super.key});

  @override
  State<StyleSelectScreen> createState() => _StyleSelectScreenState();
}

class _StyleSelectScreenState extends State<StyleSelectScreen> {
  String? _selectedFilter = '자연스러운';

  List<EyebrowStyle> get _filteredStyles {
    if (_selectedFilter == null) return kEyebrowStyles;
    return kEyebrowStyles.where((s) => s.tags.contains(_selectedFilter)).toList();
  }

  Future<void> _onApply(EyebrowStyle style) async {
    final state = context.read<AppState>();
    state.selectStyle(style);
    final success = await state.applyStyle();
    if (!mounted) return;
    if (!success && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        const AppHeader(title: '원하는 눈썹 스타일 선택', showBack: true),
        Expanded(
          child: !state.hasUploadedImage
              ? const EmptyStatePlaceholder(message: '홈에서 사진을 먼저 업로드해주세요.')
              : state.isApplying
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilterChipRow(
                            filters: kStyleFilters,
                            selected: _selectedFilter,
                            onSelected: (f) => setState(() => _selectedFilter = f),
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _filteredStyles.length,
                            itemBuilder: (context, index) {
                              final style = _filteredStyles[index];
                              return StylePreviewCard(
                                name: style.name,
                                imageBytes: state.uploadedImageBytes,
                                isLoading: state.isApplying &&
                                    state.selectedStyle?.name == style.name,
                                onApply: () => _onApply(style),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
