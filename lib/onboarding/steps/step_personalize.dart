import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/symbol/symbol_picker.dart';
import '../onboarding_provider.dart';
import '../onboarding_widgets.dart';

// Re-export so existing callers that import SymbolResult from here still work.
export '../../widgets/symbol/symbol_picker.dart'
    show SymbolResult, symbolSearchProvider;

// ─── Step Widget ──────────────────────────────────────────────────────────────

class StepPersonalize extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepPersonalize(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<StepPersonalize> createState() => _StepPersonalizeState();
}

class _StepPersonalizeState extends ConsumerState<StepPersonalize> {
  // Maps symbol id → label for chip display (provider stores IDs only).
  final Map<String, String> _symbolLabels = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final childName =
        state.childName.isNotEmpty ? state.childName : 'your child';

    return OnboardingStepShell(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeading(
            title: "Add $childName's\nfavorites",
            subtitle:
                "Search for up to 3 things they love — toys, foods, people. You'll teach them how to add symbols too.",
          ),
          const SizedBox(height: 20),

          // ── Selected favorites ─────────────────────────────────────────────
          if (state.favoriteSymbols.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: state.favoriteSymbols.map((id) {
                return Chip(
                  label: Text(_symbolLabels[id] ?? id),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => notifier.removeFavoriteSymbol(id),
                  backgroundColor: const Color(0xFFE8F5E9),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Picker / full message ──────────────────────────────────────────
          if (state.favoriteSymbols.length < 3)
            SymbolPicker(
              selectedIds: state.favoriteSymbols.toSet(),
              onSelected: (symbol) {
                _symbolLabels[symbol.id] = symbol.label;
                notifier.addFavoriteSymbol(symbol.id);
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1A8C45), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Great! 3 favorites added.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          OnboardingContinueButton(
            label: "I'm ready",
            enabled: true, // optional step — can skip
            onPressed: widget.onNext,
          ),

          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: widget.onNext,
              child: Text(
                'Skip for now',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
