// ─── Sprout AAC Onboarding ────────────────────────────────────────────────────
//
// INTEGRATION GUIDE
// ─────────────────
//
// 1. Add dependencies to pubspec.yaml:
//
//    dependencies:
//      flutter_riverpod: ^2.5.1
//      shared_preferences: ^2.2.3
//
//    flutter:
//      assets:
//        - assets/templates/little_communicator.json
//        - assets/templates/growing_voice.json
//        - assets/templates/big_talker.json
//
//
// 2. Wrap your app in ProviderScope (if not already):
//
//    void main() {
//      runApp(const ProviderScope(child: SproutApp()));
//    }
//
//
// 3. Wrap your home screen with OnboardingGate:
//
//    class SproutApp extends StatelessWidget {
//      @override
//      Widget build(BuildContext context) {
//        return MaterialApp(
//          home: OnboardingGate(
//            child: ProfileSelectionScreen(), // your existing home
//          ),
//        );
//      }
//    }
//
//    That's it. The gate reads SharedPreferences on first load:
//    - First launch → shows OnboardingFlow
//    - Subsequent launches → shows ProfileSelectionScreen directly
//
//
// 4. Consuming onboarding data in your profile/board creation:
//
//    In the final step (StepDone) after the animation, you'll want to
//    actually create the profile and board from onboarding state:
//
//    final onboardingState = ref.read(onboardingProvider);
//    await createProfileFromOnboarding(onboardingState); // your DB call
//    await ref.read(onboardingProvider.notifier).complete();
//
//    See onboarding_provider.dart for the full OnboardingState model.
//
//
// 5. Reset onboarding (for testing):
//
//    final prefs = await SharedPreferences.getInstance();
//    await prefs.remove('onboarding_complete');
//    // then hot restart

library sprout_onboarding;

export 'onboarding_flow.dart';
export 'onboarding_provider.dart';
export 'onboarding_widgets.dart';
export 'steps/step_welcome.dart';
export 'steps/step_profile.dart';
export 'steps/step_template.dart';
export 'steps/step_personalize.dart';
export 'steps/step_done.dart';
