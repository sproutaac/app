import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_theme.dart';
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
                    color: const Color(0xFF1A8C45).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                                  color: AppColors.selectedTint,
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
                assetPath: template.assetPath,
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

class _MiniGridPreview extends StatefulWidget {
  final List<String> words;
  final String assetPath;
  final int columns;

  const _MiniGridPreview({
    required this.words,
    required this.assetPath,
    required this.columns,
  });

  @override
  State<_MiniGridPreview> createState() => _MiniGridPreviewState();
}

class _MiniGridPreviewState extends State<_MiniGridPreview> {
  // label -> cell color, read from the template's OBF asset so the preview
  // always matches the board the template actually creates.
  late Future<Map<String, Color>> _colors = _loadColors(widget.assetPath);

  @override
  void didUpdateWidget(_MiniGridPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _colors = _loadColors(widget.assetPath);
    }
  }

  static Future<Map<String, Color>> _loadColors(String assetPath) async {
    final json = jsonDecode(await rootBundle.loadString(assetPath))
        as Map<String, dynamic>;
    final colors = <String, Color>{};
    for (final btn in json['buttons'] as List<dynamic>) {
      final match = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)')
          .firstMatch(btn['background_color'] as String? ?? '');
      if (match == null) continue;
      final color = Color.fromARGB(255, int.parse(match.group(1)!),
          int.parse(match.group(2)!), int.parse(match.group(3)!));
      // Lightened so the small dark labels stay readable
      colors[btn['label'] as String] = Color.lerp(color, Colors.white, 0.6)!;
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Color>>(
      future: _colors,
      builder: (context, snapshot) => _grid(snapshot.data ?? const {}),
    );
  }

  Widget _grid(Map<String, Color> colors) {
    final rows = (widget.words.length / widget.columns).ceil();
    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(widget.columns, (col) {
            final index = row * widget.columns + col;
            if (index >= widget.words.length) {
              return const Expanded(child: SizedBox());
            }
            return Expanded(
              child: Container(
                margin: const EdgeInsets.all(1.5),
                height: 28,
                decoration: BoxDecoration(
                  color: colors[widget.words[index]] ?? Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    widget.words[index],
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
