import 'package:flutter/material.dart';

// ─── Step Shell ───────────────────────────────────────────────────────────────
// Wraps every step with safe area, back button, and consistent padding.

class OnboardingStepShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;

  const OnboardingStepShell({
    super.key,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: onBack,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Heading ──────────────────────────────────────────────────────────────────

class OnboardingHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const OnboardingHeading({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F2318),
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Label ────────────────────────────────────────────────────────────────────

class OnboardingLabel extends StatelessWidget {
  final String text;
  const OnboardingLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

// ─── Choice Chip ──────────────────────────────────────────────────────────────

class ChoiceChipOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceChipOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? const Color(0xFF1A8C45) : Colors.grey.shade300,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF1A8C45)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? const Color(0xFF0F5C2E)
                    : Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Continue Button ──────────────────────────────────────────────────────────

class OnboardingContinueButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1A8C45),
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
