import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/visual_widgets.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        const AppHeader(title: 'AI 눈썹 분석', showBack: true),
        Expanded(
          child: !state.hasUploadedImage
              ? const EmptyStatePlaceholder(message: '홈에서 사진을 먼저 업로드해주세요.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(state.uploadedImageBytes!, fit: BoxFit.cover),
                              CustomPaint(painter: FaceLandmarkOverlay()),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: SizedBox(
                                    width: 148,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        MetricCard(
                                          label: '눈썹 두께',
                                          value: '중간',
                                          icon: Icons.crop_square_rounded,
                                        ),
                                        MetricCard(
                                          label: '아치 각도',
                                          value: '완만함',
                                          icon: Icons.timeline_rounded,
                                        ),
                                        MetricCard(
                                          label: '좌우 대칭도',
                                          value: '87%',
                                          icon: Icons.balance_rounded,
                                        ),
                                        MetricCard(
                                          label: '눈썹 밀도 분포',
                                          value: '',
                                          showDensityBar: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '연예인 눈썹과 유사도',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: kMockCelebrityMatches.map((m) {
                                return Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: m.showCrown ? AppColors.gold : AppColors.border,
                                              width: m.showCrown ? 2 : 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            m.styleLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                        if (m.showCrown)
                                          const Positioned(
                                            top: -8,
                                            right: -4,
                                            child: Text('👑', style: TextStyle(fontSize: 14)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(m.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(
                                      '${m.percent}%',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: '추천 스타일 보기',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => context.read<AppState>().setTab(2),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
