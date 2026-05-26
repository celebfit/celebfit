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
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '※ 분석 수치는 시범용 예시입니다 · 서비스 준비중',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: 11,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 11,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      state.uploadedImageBytes!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      filterQuality: FilterQuality.high,
                                    ),
                                    CustomPaint(painter: FaceLandmarkOverlay()),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 9,
                                child: Container(
                                  color: AppColors.background,
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: const MetricCard(
                                            label: '눈썹 두께',
                                            value: '중간',
                                            icon: Icons.crop_square_rounded,
                                            compact: true,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: const MetricCard(
                                            label: '아치 각도',
                                            value: '완만함',
                                            icon: Icons.timeline_rounded,
                                            compact: true,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: const MetricCard(
                                            label: '좌우 대칭도',
                                            value: '87%',
                                            icon: Icons.balance_rounded,
                                            compact: true,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: const MetricCard(
                                          label: '눈썹 밀도 분포',
                                          value: '',
                                          showDensityGrid: true,
                                          compact: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '85',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '눈썹 밸런스 양호',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '자연형 · 세미 아치 스타일과 잘 어울려요',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 9,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    '연예인 눈썹과 유사도',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < kMockCelebrityMatches.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      CelebrityMatchCard(match: kMockCelebrityMatches[i]),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
