// ============================================================
// symbol_picker.dart — Shared symbol search + select widget
//
// Used in:
//   • Onboarding step 4 (favourites)
//   • Cell editor (pick a symbol for a board cell)
//
// API:
//   SymbolPicker(
//     onSelected: (SymbolResult symbol) { ... },
//     selectedIds: {'123', '456'},   // shown with checkmark
//   )
//
// The widget manages its own search query state. Clears the
// field automatically after a selection.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/symbol_service.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class SymbolResult {
  final String id;
  final String label;
  final String imageUrl;

  const SymbolResult({
    required this.id,
    required this.label,
    required this.imageUrl,
  });
}

// ─── Provider ────────────────────────────────────────────────────────────────

final symbolSearchProvider =
    FutureProvider.family<List<SymbolResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final service = ref.read(symbolServiceProvider);
  final symbols = await service.search(query.trim());
  return symbols
      .map((s) => SymbolResult(id: s.id, label: s.label, imageUrl: s.imageUrl))
      .toList();
});

// ─── Widget ──────────────────────────────────────────────────────────────────

class SymbolPicker extends ConsumerStatefulWidget {
  /// Called when the user taps a result tile. The picker clears its
  /// search field automatically — the caller decides what to do next.
  final void Function(SymbolResult symbol) onSelected;

  /// IDs that are already selected; their tiles show a checkmark and
  /// cannot be tapped again.
  final Set<String> selectedIds;

  const SymbolPicker({
    super.key,
    required this.onSelected,
    this.selectedIds = const {},
  });

  @override
  ConsumerState<SymbolPicker> createState() => _SymbolPickerState();
}

class _SymbolPickerState extends ConsumerState<SymbolPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults =
        _query.isEmpty ? null : ref.watch(symbolSearchProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Search field ─────────────────────────────────────────────────────
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Search symbols (e.g. "dog", "swimming")',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
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
        ),

        // ── Results ──────────────────────────────────────────────────────────
        if (searchResults != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: searchResults.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A8C45)),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Search unavailable offline.\nYou can add symbols later.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
                        final isSelected =
                            widget.selectedIds.contains(result.id);
                        return GestureDetector(
                          onTap: isSelected
                              ? null
                              : () {
                                  widget.onSelected(result);
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                          child: _SymbolResultTile(
                            result: result,
                            selected: isSelected,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _SymbolResultTile extends StatelessWidget {
  final SymbolResult result;
  final bool selected;

  const _SymbolResultTile({required this.result, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF1A8C45) : Colors.grey.shade200,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              result.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected
                    ? const Color(0xFF1A8C45)
                    : Colors.black87,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 2),
            const Icon(Icons.check, size: 12, color: Color(0xFF1A8C45)),
          ],
        ],
      ),
    );
  }
}
