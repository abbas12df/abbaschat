import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../../core/widgets/nisaba_button.dart';
import '../../../core/theme/nisaba_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          theme.colorScheme.surface,
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                        ]
                      : [
                          theme.colorScheme.surface,
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        ],
                ),
              ),
            ),
          ),

          // Decorative glowing orb (top right)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.1, duration: 4.seconds, curve: Curves.easeInOut),

          // Decorative glowing orb (bottom left)
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.15),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.15, duration: 5.seconds, curve: Curves.easeInOut),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // App Logo
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        boxShadow: NisabaTheme.primaryGlow(theme.colorScheme.primary),
                      ),
                      child: Image.asset(
                        'assets/images/app_logo_transparent.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.chat_bubble_rounded,
                            size: 100,
                            color: theme.colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 800.ms),

                  const SizedBox(height: 48),

                  // App Title
                  Text(
                    'Nisaba',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 2.0,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),

                  const SizedBox(height: 16),

                  // Tagline
                  Text(
                    'تواصل بحرية تامة وبخصوصية مطلقة مع تشفير متطور من الطرفين.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.6,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),

                  const Spacer(flex: 4),

                  // Bottom Action Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NisabaTheme.radiusXL),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(NisabaTheme.space24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(NisabaTheme.radiusXL),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            NisabaButton(
                              text: 'إنشاء حساب جديد',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            NisabaButton(
                              text: 'تسجيل الدخول',
                              type: NisabaButtonType.secondary,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
