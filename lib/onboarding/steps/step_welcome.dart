import 'package:flutter/material.dart';

class StepWelcome extends StatelessWidget {
  final VoidCallback onNext;
  const StepWelcome({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F5C2E), Color(0xFF1A8C45)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo mark
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text('🌱', style: TextStyle(fontSize: 52)),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Sprout',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AAC',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA8F0C0),
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Let's build your child's\nfirst communication board.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Takes about 5 minutes.\nYou can change everything later.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F5C2E),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text("Let's go"),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  // TODO: navigate to OBF import screen
                  // For now, this is a no-op placeholder
                },
                child: Text(
                  'Import an existing board',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
