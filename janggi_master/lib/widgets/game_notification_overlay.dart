import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sound_manager.dart';

/// Notification types for game events
enum NotificationType {
  check,        // 장군
  escapeCheck,  // 멍군 (장군에서 벗어남)
  win,          // 승리
  lose,         // 패배
}

/// Overlay widget for game notifications with animations, sounds, and haptics
class GameNotificationOverlay extends StatefulWidget {
  final NotificationType? type;
  final String? customMessage;
  final VoidCallback? onMainMenu; // 메인 메뉴로 가기
  final VoidCallback? onRestart;  // 재시작

  const GameNotificationOverlay({
    super.key,
    this.type,
    this.customMessage,
    this.onMainMenu,
    this.onRestart,
  });

  @override
  State<GameNotificationOverlay> createState() => _GameNotificationOverlayState();
}

class _GameNotificationOverlayState extends State<GameNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _inkSplashAnimation; // For ink background reveal
  late Animation<double> _textAppearAnimation; // For check text appearance

  final SoundManager _soundManager = SoundManager();

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (widget.type != null) {
      _playEffects();
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200), // Extended for ink splash
      vsync: this,
    );

    // Ink splash animation: wipe from left to right
    _inkSplashAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    // Text appear animation: pop in after ink splash
    _textAppearAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.5, curve: Curves.easeOutBack),
    ));

    // Scale animation: EXPLOSIVE zoom in with overshoot
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    ));

    // Shake animation: violent shake effect for check
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    ));

    // Fade animation: for background dimming
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    _controller.forward();
  }

  void _playEffects() {
    // Play sound effect
    switch (widget.type!) {
      case NotificationType.check:
        _soundManager.playCheck();
        // Heavy impact vibration for check
        _triggerHaptic();
        break;
      case NotificationType.escapeCheck:
        _soundManager.playMove();
        // Light impact for escape
        HapticFeedback.lightImpact();
        break;
      case NotificationType.win:
        _soundManager.playVictory();
        // Success vibration pattern
        _triggerSuccessHaptic();
        break;
      case NotificationType.lose:
        _soundManager.playDefeat();
        // Single medium impact
        HapticFeedback.mediumImpact();
        break;
    }
  }

  void _triggerHaptic() {
    // Immediate light impact
    HapticFeedback.lightImpact();

    // Heavy impact when text "lands" (matches zoom peak)
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });

    // Additional vibration during shake
    Future.delayed(const Duration(milliseconds: 450), () {
      HapticFeedback.mediumImpact();
    });
  }

  void _triggerSuccessHaptic() {
    // Multiple light impacts for celebration
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Background dimming (for win/lose only)
            if (widget.type != NotificationType.check &&
                widget.type != NotificationType.escapeCheck)
              Positioned.fill(
                child: Opacity(
                  opacity: _fadeAnimation.value * 0.7,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
              ),

            // Main notification
            // For check: use custom animation without external transforms
            if (widget.type == NotificationType.check)
              Center(
                child: Transform.translate(
                  offset: _getShakeOffset(),
                  child: _buildNotificationContent(),
                ),
              )
            else
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildNotificationContent(),
                ),
              ),

            // Confetti effect for win (TODO: implement when confetti package is added)
            if (widget.type == NotificationType.win)
              _buildConfettiPlaceholder(),
          ],
        );
      },
    );
  }

  Offset _getShakeOffset() {
    if (widget.type != NotificationType.check) {
      return Offset.zero;
    }

    // Violent shake effect: rapid oscillation
    final shake = _shakeAnimation.value;
    // More intense shaking with sine wave pattern
    final intensity = 20.0; // Increased from 10 to 20
    final frequency = 10.0; // Multiple shakes
    final dampening = 1.0 - shake; // Gradually reduce shake

    final offsetX = intensity * dampening * math.sin(shake * frequency * math.pi);
    final offsetY = intensity * 0.3 * dampening * math.sin((shake * frequency * math.pi) + math.pi / 2); // Slight vertical shake

    return Offset(offsetX, offsetY);
  }

  Widget _buildNotificationContent() {
    final config = _getNotificationConfig();
    final isCheck = widget.type == NotificationType.check;
    final isEscapeCheck = widget.type == NotificationType.escapeCheck;
    final isWin = widget.type == NotificationType.win;
    final isLose = widget.type == NotificationType.lose;

    // Pulsating glow effect for check
    final glowIntensity = isCheck ? (_shakeAnimation.value * 0.5 + 0.5) : 1.0;

    // For notifications with background image (check, escapeCheck, win, lose), use sequential animation
    if ((isCheck || isEscapeCheck || isWin || isLose) && config.backgroundImagePath != null) {
      return _buildCheckSequentialAnimation(config, glowIntensity);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.borderColor,
          width: isCheck ? 6 : 4, // Thicker border for check
        ),
        boxShadow: [
          // Main shadow
          BoxShadow(
            color: config.shadowColor,
            blurRadius: isCheck ? 30 * glowIntensity : 20,
            spreadRadius: isCheck ? 10 * glowIntensity : 5,
          ),
          // Additional glow for check
          if (isCheck)
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4 * glowIntensity),
              blurRadius: 50,
              spreadRadius: 20,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon or Image (for single-image mode)
          if (isCheck && config.imagePath != null) ...[
            // Use image for check notification
            Image.asset(
              config.imagePath!,
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
          ] else if (config.icon != null) ...[
            // Use icon for other notifications
            Icon(
              config.icon,
              size: 60,
              color: config.textColor,
            ),
            const SizedBox(height: 16),
          ],

          // Main text
          Text(
            widget.customMessage ?? config.message,
            style: TextStyle(
              fontSize: isCheck ? 64 : 56, // Bigger for check
              fontWeight: FontWeight.w900,
              color: config.textColor,
              letterSpacing: isCheck ? 8 : 2, // More spacing for check
              shadows: [
                // Main shadow
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
                // Extra glow for check
                if (isCheck)
                  Shadow(
                    color: Colors.red.withValues(alpha: 0.8),
                    offset: Offset.zero,
                    blurRadius: 20,
                  ),
                if (isCheck)
                  Shadow(
                    color: Colors.yellow.withValues(alpha: 0.6),
                    offset: Offset.zero,
                    blurRadius: 30,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckSequentialAnimation(_NotificationConfig config, double glowIntensity) {
    // Clamp glow intensity to valid range
    final safeGlowIntensity = glowIntensity.clamp(0.0, 1.0);
    final inkProgress = _inkSplashAnimation.value.clamp(0.0, 1.0);
    final isWinOrLose = widget.type == NotificationType.win || widget.type == NotificationType.lose;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 400,
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ink background with paint brush effect (left to right)
              ClipRect(
                clipper: _HorizontalRevealClipper(inkProgress),
                child: Image.asset(
                  config.backgroundImagePath!,
                  width: 400,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),

              // Check text appearing on top after ink splash (only if foregroundImagePath is provided)
              if (config.foregroundImagePath != null && _textAppearAnimation.value > 0)
                Transform.scale(
                  scale: _textAppearAnimation.value,
                  child: Opacity(
                    opacity: _textAppearAnimation.value.clamp(0.0, 1.0),
                    child: Image.asset(
                      config.foregroundImagePath!,
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Buttons for win/lose
        if (isWinOrLose && _fadeAnimation.value > 0.5) ...[
          const SizedBox(height: 30),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 메인 메뉴 버튼
              ElevatedButton(
                onPressed: widget.onMainMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade400, width: 2),
                  ),
                ),
                child: const Text(
                  '메인 메뉴',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 20),
              // 재시작 버튼
              ElevatedButton(
                onPressed: widget.onRestart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.type == NotificationType.win
                      ? Colors.amber.shade600
                      : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '재시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildConfettiPlaceholder() {
    // TODO: Replace with actual confetti when package is added
    // For now, show simple particle effects
    return const SizedBox.shrink();

    // Future implementation:
    // return ConfettiWidget(
    //   confettiController: _confettiController,
    //   blastDirectionality: BlastDirectionality.explosive,
    //   colors: const [Colors.amber, Colors.orange, Colors.red, Colors.pink],
    // );
  }

  _NotificationConfig _getNotificationConfig() {
    switch (widget.type!) {
      case NotificationType.check:
        return _NotificationConfig(
          message: '將 軍 !',
          textColor: Colors.red.shade900,
          backgroundColor: Colors.yellow.shade50,
          borderColor: Colors.red.shade900,
          shadowColor: Colors.red.withValues(alpha: 0.8),
          icon: Icons.warning_rounded,
          backgroundImagePath: 'assets/images/장군_배경.png', // Red ink background
          foregroundImagePath: 'assets/images/장군.png', // Check text
        );

      case NotificationType.escapeCheck:
        return _NotificationConfig(
          message: '멍 군',
          textColor: Colors.blue.shade900,
          backgroundColor: Colors.white,
          borderColor: Colors.blue.shade700,
          shadowColor: Colors.blue.withValues(alpha: 0.6),
          icon: Icons.shield_outlined,
          backgroundImagePath: 'assets/images/멍군.png', // Blue ink animation (멍군_모션 renamed to 멍군.png)
          foregroundImagePath: null, // No separate text - all in one image
        );

      case NotificationType.win:
        return _NotificationConfig(
          message: '승리!',
          textColor: Colors.amber.shade700,
          backgroundColor: Colors.white,
          borderColor: Colors.amber.shade900,
          shadowColor: Colors.amber.withValues(alpha: 0.6),
          icon: Icons.emoji_events,
          backgroundImagePath: 'assets/images/승리이미지.png',
        );

      case NotificationType.lose:
        return _NotificationConfig(
          message: '패배',
          textColor: Colors.grey.shade700,
          backgroundColor: Colors.white,
          borderColor: Colors.grey.shade800,
          shadowColor: Colors.grey.withValues(alpha: 0.4),
          icon: null,
          backgroundImagePath: 'assets/images/패배이미지.png',
        );
    }
  }
}

/// Configuration for notification appearance
class _NotificationConfig {
  final String message;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final IconData? icon;
  final String? imagePath; // Path to custom image asset (single image mode)
  final String? backgroundImagePath; // Path to background image (ink splash)
  final String? foregroundImagePath; // Path to foreground image (check text)

  _NotificationConfig({
    required this.message,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    this.icon,
    this.imagePath,
    this.backgroundImagePath,
    this.foregroundImagePath,
  });
}

/// Custom clipper for horizontal reveal effect (paint brush effect)
class _HorizontalRevealClipper extends CustomClipper<Rect> {
  final double progress;

  _HorizontalRevealClipper(this.progress);

  @override
  Rect getClip(Size size) {
    // Reveal from left to right based on progress (0.0 to 1.0)
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
