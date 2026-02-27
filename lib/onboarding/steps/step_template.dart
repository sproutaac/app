import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_provider.dart';
import '../onboarding_widgets.dart';

class StepTemplate extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepTemplate({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final childName =
        state.childName.isNotEmpty ? state.childName : 'your child';

    return OnboardingStepShell(
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeading(
            title: "Pick $childName's\nstarter board",
            subtitle: "We've pre-selected based on their age. You can always add more words later.",
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: StarterTemplate.values.map((template) {
                final selected = state.selectedTemplate == template;
                final isRecommended = state.ageRange != null &&
                    StarterTemplate.forAgeRange(state.ageRange!) == template;

                return _TemplateCard(
                  template: template,
                  selected: selected,
                  recommended: isRecommended,
                  onTap: () => notifier.setTemplate(template),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Import link
          Center(
            child: TextButton.icon(
              onPressed: () {
                // TODO: OBF import
              },
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Import an existing board (.obf)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 8),

          OnboardingContinueButton(
            label: 'Add a personal touch',
            enabled: state.selectedTemplate != null,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final StarterTemplate template;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF1A8C45)
                : Colors.grey.shade200,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A8C45).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              template.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (recommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Recommended',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A8C45),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${template.gridSize} · ${template.wordCount} words · Ages ${template.ageRange.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF1A8C45), size: 24),
                ],
              ),

              const SizedBox(height: 10),
              Text(
                template.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 12),

              // Mini grid preview
              _MiniGridPreview(
                words: template.previewWords,
                columns: template.ageRange == AgeRange.toddler
                    ? 3
                    : template.ageRange == AgeRange.child
                        ? 4
                        : 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini Grid Preview ────────────────────────────────────────────────────────

class _MiniGridPreview extends StatelessWidget {
  final List<String> words;
  final int columns;

  const _MiniGridPreview({required this.words, required this.columns});

  Color _cellColor(int index) {
    // Approximate Fitzgerald Key coloring based on position in our templates
    final colorsByPosition = [
      // Row 0: pronouns/social → yellow, or verbs → green
      [Colors.amber.shade200, Colors.amber.shade200, Colors.amber.shade200, Colors.amber.shade200, Colors.orange.shade200],
      // Row 1: verbs → green, negation → red
      [Colors.green.shade200, Colors.green.shade200, Colors.green.shade200, Colors.green.shade200, Colors.red.shade200],
      // Row 2: verbs/descriptors → green, negation → red
      [Colors.green.shade200, Colors.red.shade200, Colors.green.shade200, Colors.green.shade200, Colors.green.shade200],
      // Row 3: descriptors → purple
      [Colors.purple.shade100, Colors.purple.shade100, Colors.purple.shade100, Colors.purple.shade100, Colors.red.shade200],
      // Row 4: nouns/actions → orange, yes/no → blue/red
      [Colors.orange.shade200, Colors.orange.shade200, Colors.green.shade200, Colors.blue.shade200, Colors.red.shade200],
    ];

    final row = index ~/ columns;
    final col = index % columns;
    if (row < colorsByPosition.length && col < colorsByPosition[row].length) {
      return colorsByPosition[row][col];
    }
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final rows = (words.length / columns).ceil();
    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(columns, (col) {
            final index = row * columns + col;
            if (index >= words.length) {
              return const Expanded(child: SizedBox());
            }
            return Expanded(
              child: Container(
                margin: const EdgeInsets.all(1.5),
                height: 28,
                decoration: BoxDecoration(
                  color: _cellColor(index),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    words[index],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
