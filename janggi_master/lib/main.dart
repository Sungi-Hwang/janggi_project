import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/game_screen.dart' show GameScreen, GameMode;
import 'models/piece.dart' show PieceColor;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Janggi Master',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4AF37)),
        useMaterial3: true,
      ),
      home: const MainMenu(),
    );
  }
}

/// Main menu screen with glassmorphism design
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title: 장기 마스터
              Text(
                '장기 마스터',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 4),
                      blurRadius: 12.0,
                      color: Colors.black.withOpacity(0.8),
                    ),
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 8.0,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle: Janggi Master
              Text(
                'Janggi Master',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 8.0,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // 1. Play vs AI Button - Cyan Neon
              _buildMenuButton(
                context: context,
                label: 'AI 대국',
                icon: Icons.smart_toy,
                gradientColors: const [Color(0xFF0a4d68), Color(0xFF05161a)],
                neonColor: const Color(0xFF00d9ff),
                onTap: () => _showAIDifficultyDialog(context),
              ),
              const SizedBox(height: 16),

              // 2. Play vs Player Button - Green Neon
              _buildMenuButton(
                context: context,
                label: '친구 대국',
                icon: Icons.people,
                gradientColors: const [Color(0xFF0a4d1a), Color(0xFF051a08)],
                neonColor: const Color(0xFF00ff88),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GameScreen(gameMode: GameMode.twoPlayer),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 3. Puzzles Button - Purple Neon
              _buildMenuButton(
                context: context,
                label: '묘수풀이',
                icon: Icons.extension,
                gradientColors: const [Color(0xFF4d0a68), Color(0xFF1a0522)],
                neonColor: const Color(0xFFd900ff),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('준비중입니다!')),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 4. Settings Button - Orange Neon
              _buildMenuButton(
                context: context,
                label: '설정',
                icon: Icons.settings,
                gradientColors: const [Color(0xFF4d2a0a), Color(0xFF1a1005)],
                neonColor: const Color(0xFFff9900),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('준비중입니다!')),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Features Box - Glassmorphism
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Features:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem('✓ Offline AI powered by Fairy-Stockfish'),
                        const SizedBox(height: 8),
                        _buildFeatureItem('✓ Traditional Janggi rules'),
                        const SizedBox(height: 8),
                        _buildFeatureItem('✓ Beautiful board visualization'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Build a neon-styled menu button
  Widget _buildMenuButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required Color neonColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 320,
        height: 65,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: neonColor,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: neonColor.withOpacity(0.8),
              blurRadius: 25,
              spreadRadius: 3,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: neonColor.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: neonColor.withOpacity(0.4),
              blurRadius: 50,
              spreadRadius: -5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: neonColor,
              shadows: [
                Shadow(
                  color: neonColor,
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: neonColor,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: neonColor,
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                  Shadow(
                    color: neonColor,
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show AI difficulty selection dialog
  void _showAIDifficultyDialog(BuildContext context) {
    int selectedDifficulty = 10;
    PieceColor selectedAIColor = PieceColor.red;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('AI 대국 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI Color Selection
                  const Text('AI 진영:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButton<PieceColor>(
                    value: selectedAIColor,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: PieceColor.red,
                        child: Text('한 (Red) - AI가 한나라'),
                      ),
                      DropdownMenuItem(
                        value: PieceColor.blue,
                        child: Text('초 (Blue) - AI가 초나라'),
                      ),
                    ],
                    onChanged: (PieceColor? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedAIColor = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  // AI Difficulty Selection
                  const Text('AI 난이도:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.child_care, color: Colors.green),
                    title: const Text('초급'),
                    subtitle: const Text('초보자용 - 쉬운 난이도'),
                    selected: selectedDifficulty == 5,
                    onTap: () {
                      setState(() {
                        selectedDifficulty = 5;
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.orange),
                    title: const Text('중급'),
                    subtitle: const Text('중간 난이도'),
                    selected: selectedDifficulty == 10,
                    onTap: () {
                      setState(() {
                        selectedDifficulty = 10;
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Colors.red),
                    title: const Text('고급'),
                    subtitle: const Text('프로 수준 - 어려운 난이도'),
                    selected: selectedDifficulty == 15,
                    onTap: () {
                      setState(() {
                        selectedDifficulty = 15;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameScreen(
                          gameMode: GameMode.vsAI,
                          aiDifficulty: selectedDifficulty,
                          aiColor: selectedAIColor,
                        ),
                      ),
                    );
                  },
                  child: const Text('시작'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
