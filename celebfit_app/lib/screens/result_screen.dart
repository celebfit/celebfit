import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/visual_widgets.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        const AppHeader(title: '스타일 적용 결과', showBack: true, showShare: true),
        Expanded(
          child: !state.hasResult
              ? const EmptyStatePlaceholder(message: '스타일 탭에서 스타일을 적용해주세요.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      BeforeAfterSlider(
                        beforeBytes: state.resultBeforeBytes!,
                        afterBytes: state.resultAfterBytes!,
                      ),
                      if (state.resultEngine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '엔진: ${state.resultEngine}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.favorite, color: AppColors.heart, size: 20),
                                SizedBox(width: 6),
                                Text('어울림 점수', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                SizedBox(width: 6),
                                Text(
                                  '92%',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '현재 얼굴형과 눈썹에 잘 어울리는 스타일이에요',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ...kMockResultScores.map(
                              (s) => ProgressScoreRow(label: s.label, percent: s.value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                context.read<AppState>().resetResult();
                                context.read<AppState>().setTab(2);
                              },
                              child: const Text('다른 스타일 비교'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('저장하기'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: '상담 예약',
                        icon: Icons.calendar_today_outlined,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
