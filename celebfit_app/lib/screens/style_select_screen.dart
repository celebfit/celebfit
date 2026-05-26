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
  CelebGender _gender = CelebGender.female;

  List<EyebrowStyle> get _visibleStyles {
    return _gender == CelebGender.female ? kFemaleEyebrowStyles : kMaleEyebrowStyles;
  }

  Future<void> _onApply(EyebrowStyle style) async {
    if (!style.apiEnabled) return;

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
    final styles = _visibleStyles;

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
                          GenderBanner(
                            selected: _gender,
                            onChanged: (gender) => setState(() => _gender = gender),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _gender == CelebGender.female
                                ? 'AI 변환 가능 · 여성 연예인 눈썹 스타일'
                                : '남성 연예인 스타일 · 서비스 준비중',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                            itemCount: styles.length,
                            itemBuilder: (context, index) {
                              final style = styles[index];
                              return StylePreviewCard(
                                compact: true,
                                name: style.name,
                                subtitle: style.subtitle,
                                previewAsset: style.previewAsset,
                                enabled: style.apiEnabled,
                                isLoading:
                                    state.isApplying && state.selectedStyle?.id == style.id,
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
