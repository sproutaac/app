import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_provider.dart';
import '../onboarding_widgets.dart';

class StepProfile extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepProfile({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<StepProfile> createState() => _StepProfileState();
}

class _StepProfileState extends ConsumerState<StepProfile> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    final state = ref.read(onboardingProvider);
    return state.childName.isNotEmpty && state.ageRange != null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    // Sync controller with state (in case of back-navigation)
    if (_nameController.text != state.childName) {
      _nameController.text = state.childName;
      _nameController.selection =
          TextSelection.collapsed(offset: state.childName.length);
    }

    final childFirstName =
        state.childName.isNotEmpty ? state.childName : 'your child';

    return OnboardingStepShell(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeading(
            title: "Tell us about\nyour child",
            subtitle: "Just three quick questions.",
          ),
          const SizedBox(height: 32),

          // ── Name ──────────────────────────────────────────────────────────
          OnboardingLabel("What's their name?"),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'First name',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF1A8C45), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: notifier.setChildName,
          ),

          const SizedBox(height: 28),

          // ── Age range ─────────────────────────────────────────────────────
          OnboardingLabel("How old is $childFirstName?"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: AgeRange.values.map((age) {
              final selected = state.ageRange == age;
              return ChoiceChipOption(
                label: age.label,
                selected: selected,
                onTap: () => notifier.setAgeRange(age),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // ── Access method ─────────────────────────────────────────────────
          OnboardingLabel("How will $childFirstName use the app?"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChipOption(
                label: 'Touch screen',
                icon: Icons.touch_app_outlined,
                selected: state.accessMethod == AccessMethod.touch,
                onTap: () => notifier.setAccessMethod(AccessMethod.touch),
              ),
              ChoiceChipOption(
                label: 'Switch access',
                icon: Icons.accessibility_new_outlined,
                selected: state.accessMethod == AccessMethod.switchAccess,
                onTap: () =>
                    notifier.setAccessMethod(AccessMethod.switchAccess),
              ),
              ChoiceChipOption(
                label: 'Eye gaze',
                icon: Icons.visibility_outlined,
                selected: state.accessMethod == AccessMethod.eyeGaze,
                onTap: () => notifier.setAccessMethod(AccessMethod.eyeGaze),
              ),
              ChoiceChipOption(
                label: "I'll set up later",
                selected: state.accessMethod == AccessMethod.setupLater,
                onTap: () =>
                    notifier.setAccessMethod(AccessMethod.setupLater),
              ),
            ],
          ),

          const Spacer(),

          OnboardingContinueButton(
            label: 'Choose a starter board',
            enabled: _canContinue,
            onPressed: widget.onNext,
          ),
        ],
      ),
    );
  }
}
