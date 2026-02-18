import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/piece.dart' show PieceColor;
import 'providers/settings_provider.dart';
import 'screens/custom_puzzle_editor_screen.dart';
import 'screens/game_screen.dart' show GameMode, GameScreen;
import 'screens/puzzle_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'services/sound_manager.dart';

const bool kAutoAiTest =
    bool.fromEnvironment('AUTO_AI_TEST', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  SoundManager().setSoundEnabled(settingsService.soundEnabled);
  SoundManager().setVolume(settingsService.soundVolume);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    SoundManager().setSoundEnabled(settings.soundEnabled);
    SoundManager().setVolume(settings.soundVolume);

    return MaterialApp(
      title: '장기한수 (Janggi Hansu)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3E2723),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: kAutoAiTest
          ? const GameScreen(
              gameMode: GameMode.vsAI,
              aiDifficulty: 5,
              aiColor: PieceColor.red,
            )
          : const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final titleSize =
                            (MediaQuery.of(context).size.width * 0.12)
                                .clamp(40.0, 60.0);
                        final subtitleSize =
                            (MediaQuery.of(context).size.width * 0.06)
                                .clamp(20.0, 28.0);

                        return Column(
                          children: [
                            Text(
                              '장기한수',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                    color: Colors.black.withValues(alpha: 0.8),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Janggi Hansu',
                              style: TextStyle(
                                fontSize: subtitleSize,
                                fontWeight: FontWeight.w300,
                                color: Colors.white70,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                    _buildMenuButton(
                      context: context,
                      label: 'AI 대국',
                      icon: Icons.smart_toy,
                      gradientColors: const [
                        Color(0xFF0A4D68),
                        Color(0xFF05161A),
                      ],
                      neonColor: const Color(0xFF00D9FF),
                      onTap: () {
                        final settings = context.read<SettingsProvider>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              gameMode: GameMode.vsAI,
                              aiDifficulty: settings.aiDifficulty,
                              aiThinkingTimeSec: settings.aiThinkingTime,
                              aiColor: PieceColor.red,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      label: '친구 대국',
                      icon: Icons.people,
                      gradientColors: const [
                        Color(0xFF0A4D1A),
                        Color(0xFF051A08),
                      ],
                      neonColor: const Color(0xFF00FF88),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GameScreen(
                              gameMode: GameMode.twoPlayer,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      label: '이어하기 대국',
                      icon: Icons.smart_toy,
                      gradientColors: const [
                        Color(0xFF0A3B4D),
                        Color(0xFF051218),
                      ],
                      neonColor: const Color(0xFF00E5FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomPuzzleEditorScreen(
                              mode: CustomPuzzleEditorMode.aiContinue,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      label: '묘수풀이',
                      icon: Icons.extension,
                      gradientColors: const [
                        Color(0xFF4D0A68),
                        Color(0xFF1A0522),
                      ],
                      neonColor: const Color(0xFFD900FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PuzzleListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      label: '설정',
                      icon: Icons.settings,
                      gradientColors: const [
                        Color(0xFF4D2A0A),
                        Color(0xFF1A1005),
                      ],
                      neonColor: const Color(0xFFFF9900),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required Color neonColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth * 0.85).clamp(280.0, 320.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: buttonWidth,
        height: 65,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: neonColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: neonColor.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: neonColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: neonColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
