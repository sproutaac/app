import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_provider.dart';
import '../onboarding_widgets.dart';

// ─── Symbol Search Result Model ───────────────────────────────────────────────
// In production this would come from OpenSymbols API.
// Here we use a local stub that you can wire up later.

class SymbolResult {
  final String id;
  final String label;
  final String imageUrl; // OpenSymbols URL
  const SymbolResult({
    required this.id,
    required this.label,
    required this.imageUrl,
  });
}

// Stub provider — replace with real OpenSymbols search
final symbolSearchProvider =
    FutureProvider.family<List<SymbolResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  // TODO: replace with real call to https://www.opensymbols.org/api/v2/symbols?q=...
  await Future.delayed(const Duration(milliseconds: 400)); // simulate network
  return [
    SymbolResult(
        id: 'stub-${query.toLowerCase().replaceAll(' ', '-')}-1',
        label: query,
        imageUrl:
            'https://d18vdu4p71yql0.cloudfront.net/libraries/arasaac/1.png'),
    SymbolResult(
        id: 'stub-${query.toLowerCase().replaceAll(' ', '-')}-2',
        label: '$query (2)',
        imageUrl:
            'https://d18vdu4p71yql0.cloudfront.net/libraries/arasaac/2.png'),
    SymbolResult(
        id: 'stub-${query.toLowerCase().replaceAll(' ', '-')}-3',
        label: '$query (3)',
        imageUrl:
            'https://d18vdu4p71yql0.cloudfront.net/libraries/arasaac/3.png'),
  ];
});

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
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final childName =
        state.childName.isNotEmpty ? state.childName : 'your child';
    final searchResults =
        _query.isEmpty ? null : ref.watch(symbolSearchProvider(_query));

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

          // ── Selected favorites ────────────────────────────────────────────
          if (state.favoriteSymbols.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: state.favoriteSymbols.map((id) {
                return Chip(
                  label: Text(id.replaceAll('stub-', '').split('-').first),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => notifier.removeFavoriteSymbol(id),
                  backgroundColor: const Color(0xFFE8F5E9),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Search ────────────────────────────────────────────────────────
          if (state.favoriteSymbols.length < 3) ...[
            TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Search symbols (e.g. "dog", "swimming")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
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
                  borderSide:
                      const BorderSide(color: Color(0xFF1A8C45), width: 2),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),

            // ── Search Results ──────────────────────────────────────────────
            if (searchResults != null)
              SizedBox(
                height: 130,
                child: searchResults.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1A8C45)),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      'Search unavailable offline.\nYou can add symbols in the editor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                  data: (results) => results.isEmpty
                      ? Center(
                          child: Text(
                            'No symbols found for "$_query"',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final result = results[i];
                            final alreadyAdded = state.favoriteSymbols
                                .contains(result.id);
                            return GestureDetector(
                              onTap: alreadyAdded
                                  ? null
                                  : () {
                                      notifier
                                          .addFavoriteSymbol(result.id);
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                              child: _SymbolTile(
                                result: result,
                                added: alreadyAdded,
                              ),
                            );
                          },
                        ),
                ),
              ),
          ] else ...[
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
                    "Great! 3 favorites added.",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

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

// ─── Symbol Tile ──────────────────────────────────────────────────────────────

class _SymbolTile extends StatelessWidget {
  final SymbolResult result;
  final bool added;

  const _SymbolTile({required this.result, required this.added});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: added ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              added ? const Color(0xFF1A8C45) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.network(
              result.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: added ? const Color(0xFF1A8C45) : Colors.black87,
            ),
          ),
          if (added) ...[
            const SizedBox(height: 2),
            const Icon(Icons.check, size: 12, color: Color(0xFF1A8C45)),
          ],
        ],
      ),
    );
  }
}
