import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
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
                    subtitle: const Text('기물 이동, 장군/멍군 등 효과음'),
                    value: settings.soundEnabled,
                    activeColor: Colors.brown,
                    onChanged: (value) => settings.setSoundEnabled(value),
                  ),
                  ListTile(
                    title: const Text('사운드 볼륨'),
                    subtitle: Slider(
                      value: settings.soundVolume,
                      onChanged: settings.soundEnabled
                          ? (value) => settings.setSoundVolume(value)
                          : null,
                      activeColor: Colors.brown,
                    ),
                    trailing: Text('${(settings.soundVolume * 100).round()}%'),
                  ),
                ],
              ),
              const Divider(),
              _buildSection(
                title: '게임 설정',
                children: [
                  ListTile(
                    title: const Text('AI 난이도 (Depth)'),
                    subtitle: Text('현재: ${settings.aiDifficulty}'),
                    trailing: DropdownButton<int>(
                      value: settings.aiDifficulty,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 (입문)')),
                        DropdownMenuItem(value: 3, child: Text('3 (초급)')),
                        DropdownMenuItem(value: 5, child: Text('5 (보통)')),
                        DropdownMenuItem(value: 7, child: Text('7 (중급)')),
                        DropdownMenuItem(value: 9, child: Text('9 (강함)')),
                        DropdownMenuItem(value: 11, child: Text('11 (고급)')),
                        DropdownMenuItem(value: 13, child: Text('13 (고수)')),
                        DropdownMenuItem(value: 15, child: Text('15 (프로)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setAiDifficulty(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('AI 생각시간'),
                    subtitle: Text('최대 ${settings.aiThinkingTime}초'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: settings.aiThinkingTime.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        onChanged: (value) {
                          settings.setAiThinkingTime(value.toInt());
                        },
                        activeColor: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildSection(
                title: '디자인',
                children: [
                  ListTile(
                    title: const Text('장기판 디자인'),
                    subtitle: Text(_boardSkinLabel(settings.boardSkin)),
                    trailing: DropdownButton<String>(
                      value: settings.boardSkin,
                      items: const [
                        DropdownMenuItem(value: 'wood', child: Text('우드')),
                        DropdownMenuItem(value: 'classic', child: Text('클래식')),
                        DropdownMenuItem(value: 'dark', child: Text('다크')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setBoardSkin(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('장기알 디자인'),
                    subtitle:
                        Text(settings.pieceSkin == 'traditional' ? '전통' : '모던'),
                    trailing: DropdownButton<String>(
                      value: settings.pieceSkin,
                      items: const [
                        DropdownMenuItem(
                            value: 'traditional', child: Text('전통')),
                        DropdownMenuItem(value: 'modern', child: Text('모던')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setPieceSkin(value);
                        }
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('좌표 표시'),
                    subtitle: const Text('보드 가장자리에 숫자 좌표 표시'),
                    value: settings.showCoordinates,
                    activeColor: Colors.brown,
                    onChanged: (value) => settings.setShowCoordinates(value),
                  ),
                ],
              ),
              const Divider(),
              _buildSection(
                title: '언어',
                children: [
                  ListTile(
                    title: const Text('Language'),
                    subtitle:
                        Text(settings.language == 'ko' ? '한국어' : 'English'),
                    trailing: DropdownButton<String>(
                      value: settings.language,
                      items: const [
                        DropdownMenuItem(value: 'ko', child: Text('한국어')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) {
                        if (value != null) settings.setLanguage(value);
                      },
                    ),
                  ),
                ],
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('장기한수 v1.1.0',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        showAboutDialog(
                          context: context,
                          applicationName: '장기한수',
                          applicationVersion: '1.1.0',
                          applicationLegalese:
                              '© 2026 Janggi Hansu Team\nEngine: Fairy-Stockfish (Stockfish, GPLv3)',
                          children: const [
                            SizedBox(height: 8),
                            Text(
                                'This app includes Fairy-Stockfish, derived from Stockfish.'),
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

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
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

  String _boardSkinLabel(String value) {
    switch (value) {
      case 'classic':
        return '클래식';
      case 'dark':
        return '다크';
      case 'wood':
      default:
        return '우드';
    }
  }
}
