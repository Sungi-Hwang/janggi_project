import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../providers/monetization_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/janggi_skin.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<int> _difficultyValues = <int>[1, 3, 5, 7, 9, 11, 13, 15];

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final monetization = context.watch<MonetizationProvider>();

        final clampedDifficulty =
            monetization.enforceDifficultyLimit(settings.aiDifficulty);
        final clampedThinkingTime =
            monetization.enforceThinkingTimeLimit(settings.aiThinkingTime);

        if (clampedDifficulty != settings.aiDifficulty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            settings.setAiDifficulty(clampedDifficulty);
          });
        }

        if (clampedThinkingTime != settings.aiThinkingTime) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            settings.setAiThinkingTime(clampedThinkingTime);
          });
        }

        final maxThinkingTime = monetization.maxThinkingTimeSec;

        return Scaffold(
          appBar: AppBar(
            title: const Text('설정'),
            backgroundColor: const Color(0xFF3E2723),
            foregroundColor: Colors.white,
          ),
          body: ListView(
            children: [
              _buildSection(
                title: '사운드',
                children: [
                  SwitchListTile(
                    title: const Text('효과음 사용'),
                    subtitle: const Text('이동, 장군, 승패 효과음을 재생합니다.'),
                    value: settings.soundEnabled,
                    activeThumbColor: Colors.brown,
                    onChanged: settings.setSoundEnabled,
                  ),
                  ListTile(
                    title: const Text('효과음 볼륨'),
                    subtitle: Slider(
                      value: settings.soundVolume,
                      onChanged: settings.soundEnabled
                          ? settings.setSoundVolume
                          : null,
                      activeColor: Colors.brown,
                    ),
                    trailing: Text('${(settings.soundVolume * 100).round()}%'),
                  ),
                ],
              ),
              const Divider(height: 1),
              _buildSection(
                title: '게임 설정',
                children: [
                  ListTile(
                    title: const Text('AI 난이도'),
                    subtitle: Text('현재: ${_difficultyLabel(clampedDifficulty)}'),
                    trailing: DropdownButton<int>(
                      value: clampedDifficulty,
                      items: _difficultyValues.map((value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(_difficultyLabel(value)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        settings.setAiDifficulty(value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('AI 생각 시간'),
                    subtitle: Text(
                      '현재: $clampedThinkingTime초 (최대 $maxThinkingTime초)',
                    ),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: clampedThinkingTime.toDouble(),
                        min: 1,
                        max: maxThinkingTime.toDouble(),
                        divisions: maxThinkingTime - 1,
                        onChanged: (value) {
                          settings.setAiThinkingTime(
                            monetization.enforceThinkingTimeLimit(
                              value.toInt(),
                            ),
                          );
                        },
                        activeColor: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              _buildSection(
                title: '광고',
                children: [
                  ListTile(
                    title: Text(
                      monetization.isAdFree ? '광고 제거 활성화됨' : '광고 포함 버전',
                    ),
                    subtitle: Text(
                      monetization.isAdFree
                          ? '배너와 전면 광고가 더 이상 표시되지 않습니다.'
                          : '핵심 기능은 모두 무료이며, 원하면 광고만 제거할 수 있습니다.',
                    ),
                    trailing: monetization.purchasePending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  if (!monetization.isAdFree)
                    ListTile(
                      title: Text(
                        '광고 제거 (${_priceOrFallback(monetization.removeAdsProduct, '불러오는 중...')})',
                      ),
                      subtitle: const Text('배너와 전면 광고 제거'),
                      trailing: FilledButton(
                        onPressed: monetization.purchasePending
                            ? null
                            : monetization.buyRemoveAds,
                        child: const Text('구매'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: monetization.purchasePending
                            ? null
                            : monetization.restorePurchases,
                        child: const Text('구매 복원'),
                      ),
                    ),
                  ),
                  if (monetization.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        monetization.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              const Divider(height: 1),
              _buildSection(
                title: '보드와 말',
                children: [
                  ListTile(
                    title: const Text('보드 스킨'),
                    subtitle: Text(JanggiSkin.boardLabel(settings.boardSkin)),
                    trailing: DropdownButton<String>(
                      value: settings.boardSkin,
                      items: const [
                        DropdownMenuItem(
                          value: JanggiSkin.boardKoreanWood,
                          child: Text('한국 장기판'),
                        ),
                        DropdownMenuItem(
                          value: JanggiSkin.boardLegacyGold,
                          child: Text('금빛 보드'),
                        ),
                        DropdownMenuItem(
                          value: JanggiSkin.boardClassic,
                          child: Text('클래식'),
                        ),
                        DropdownMenuItem(
                          value: JanggiSkin.boardDark,
                          child: Text('다크'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        settings.setBoardSkin(value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('말 스킨'),
                    subtitle: Text(JanggiSkin.pieceLabel(settings.pieceSkin)),
                    trailing: DropdownButton<String>(
                      value: settings.pieceSkin,
                      items: const [
                        DropdownMenuItem(
                          value: JanggiSkin.pieceTraditional,
                          child: Text('한국 전통'),
                        ),
                        DropdownMenuItem(
                          value: JanggiSkin.pieceLegacyGold,
                          child: Text('금빛 전통'),
                        ),
                        DropdownMenuItem(
                          value: JanggiSkin.pieceModern,
                          child: Text('모던'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        settings.setPieceSkin(value);
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('좌표 표시'),
                    subtitle: const Text('보드 가장자리에 숫자 좌표를 표시합니다.'),
                    value: settings.showCoordinates,
                    activeThumbColor: Colors.brown,
                    onChanged: settings.setShowCoordinates,
                  ),
                ],
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      '장기 한수 Beta',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        showAboutDialog(
                          context: context,
                          applicationName: '장기 한수',
                          applicationVersion: 'Beta',
                          applicationLegalese:
                              '© 2026 Janggi Hansu Team\nEngine: Fairy-Stockfish (Stockfish, GPLv3)',
                          children: const [
                            SizedBox(height: 8),
                            Text(
                              'This app includes Fairy-Stockfish, derived from Stockfish.',
                            ),
                            Text('Licensed under GNU GPL v3.0.'),
                          ],
                        );
                      },
                      child: const Text('앱 정보 및 라이선스'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  static String _difficultyLabel(int value) {
    return switch (value) {
      1 => '1 (입문)',
      3 => '3 (초급)',
      5 => '5 (보통)',
      7 => '7 (중급)',
      9 => '9 (강함)',
      11 => '11 (고급)',
      13 => '13 (고수)',
      15 => '15 (프로)',
      _ => '$value',
    };
  }

  String _priceOrFallback(ProductDetails? product, String fallback) {
    return product?.price ?? fallback;
  }
}
