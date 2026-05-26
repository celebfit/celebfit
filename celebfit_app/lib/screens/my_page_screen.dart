import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late final TextEditingController _apiController;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      _apiController.text = context.read<AppState>().apiBaseUrl ?? '';
      _controllerInitialized = true;
    }
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _saveAndCheck() async {
    final state = context.read<AppState>();
    await state.setApiBaseUrl(_apiController.text);
    if (!mounted) return;
    await state.checkServerHealth();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        const AppHeader(showLogo: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, size: 32, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  '게스트',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Text(
                  '로그인하고 결과를 저장하세요',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API 서버 설정',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'RunPod GPU 서버 URL 또는 Mac IP를 입력하세요.\n'
                        '예: https://xxxxx-8000.proxy.runpod.net\n'
                        '또는 http://192.168.0.10:8000',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiController,
                        decoration: const InputDecoration(
                          hintText: 'https://xxxxx-8000.proxy.runpod.net',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.isCheckingServer ? null : _saveAndCheck,
                              child: state.isCheckingServer
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('저장 · 연결 확인'),
                            ),
                          ),
                        ],
                      ),
                      if (state.serverStatusMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          state.serverStatusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: state.serverStatusMessage!.startsWith('연결됨')
                                ? Colors.green.shade700
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  items: const [
                    _MenuRow(label: '적용 기록'),
                    _MenuRow(label: '찜한 스타일'),
                    _MenuRow(label: '저장한 결과'),
                  ],
                ),
                const SizedBox(height: 20),
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});
  final List<_MenuRow> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14))),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuRow {
  const _MenuRow({required this.label});
  final String label;
}
