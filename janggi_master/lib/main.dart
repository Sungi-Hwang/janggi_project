import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/game_screen.dart';

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

              // Play vs AI Button - SF Neon Design
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 320,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0a4d68), // Dark teal
                        Color(0xFF05161a), // Very dark blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: const Color(0xFF00d9ff),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00d9ff).withOpacity(0.8),
                        blurRadius: 25,
                        spreadRadius: 3,
                        offset: const Offset(0, 0),
                      ),
                      BoxShadow(
                        color: const Color(0xFF00d9ff).withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: const Offset(0, 0),
                      ),
                      const BoxShadow(
                        color: Color(0x6600d9ff),
                        blurRadius: 50,
                        spreadRadius: -5,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        size: 36,
                        color: Color(0xFF00d9ff),
                        shadows: [
                          Shadow(
                            color: Color(0xFF00d9ff),
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Play vs AI',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00d9ff),
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Color(0xFF00d9ff),
                              blurRadius: 10,
                              offset: Offset(0, 0),
                            ),
                            Shadow(
                              color: Color(0xFF00d9ff),
                              blurRadius: 20,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
}
