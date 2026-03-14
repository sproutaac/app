// ============================================================
// cell_editor_sheet.dart — Modal bottom sheet for editing a cell
//
// Handles both new cells (cell == null) and existing cells.
// Fields: label, symbol picker, background colour, action type,
//         optional speak-text override.
// ============================================================

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import '../../models/database.dart';
import '../../widgets/symbol/symbol_picker.dart';

class CellEditorSheet extends StatefulWidget {
  final BoardCell? cell; // null = new cell
  final int row;
  final int col;
  final int boardId;
  final AppDatabase db;

  const CellEditorSheet({
    super.key,
    required this.cell,
    required this.row,
    required this.col,
    required this.boardId,
    required this.db,
  });

  @override
  State<CellEditorSheet> createState() => _CellEditorSheetState();
}

class _CellEditorSheetState extends State<CellEditorSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _speakController;
  late Color _bgColor;
  late String _actionType;
  String? _symbolId;
  String? _symbolUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cell;
    _labelController = TextEditingController(text: c?.label ?? '');
    _speakController = TextEditingController(text: c?.speakText ?? '');
    _bgColor = c != null ? _parseColor(c.backgroundColor) : AppColors.primary;
    _actionType = c?.actionType ?? 'speak';
    _symbolId = c?.symbolId;
    _symbolUrl = c?.symbolUrl;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _speakController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  // Extracts RGB as '#RRGGBB'.
  String _colorToHex(Color c) {
    final r = c.r.round().toRadixString(16).padLeft(2, '0');
    final g = c.g.round().toRadixString(16).padLeft(2, '0');
    final b = c.b.round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  // Pick white or black text based on background luminance.
  String get _textColorHex =>
      _bgColor.computeLuminance() < 0.3 ? '#FFFFFF' : '#000000';

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;

    setState(() => _saving = true);

    await widget.db.upsertCell(BoardCellsCompanion(
      id: widget.cell != null
          ? Value(widget.cell!.id)
          : const Value.absent(),
      boardId: Value(widget.boardId),
      rowIndex: Value(widget.row),
      colIndex: Value(widget.col),
      label: Value(label),
      symbolId: Value(_symbolId),
      symbolUrl: Value(_symbolUrl),
      backgroundColor: Value(_colorToHex(_bgColor)),
      textColor: Value(_textColorHex),
      actionType: Value(_actionType),
      speakText: _speakController.text.trim().isNotEmpty
          ? Value(_speakController.text.trim())
          : const Value(null),
      updatedAt: Value(DateTime.now()),
    ));

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.cell == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete cell?'),
        content: Text(
            'Remove "${widget.cell!.label}" from the board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.db.deleteCell(widget.cell!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.cell == null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ───────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title + delete ────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  isNew ? 'New Cell' : 'Edit Cell',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!isNew)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: 'Delete cell',
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Label ─────────────────────────────────────────────────────────
            const _SectionLabel('Label'),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. "more", "dog", "help"',
              ),
            ),
            const SizedBox(height: 20),

            // ── Symbol ────────────────────────────────────────────────────────
            const _SectionLabel('Symbol'),
            const SizedBox(height: 8),

            // Current symbol preview + remove
            if (_symbolUrl != null) ...[
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      _symbolUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600),
                    onPressed: () => setState(() {
                      _symbolId = null;
                      _symbolUrl = null;
                    }),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            SymbolPicker(
              selectedIds: _symbolId != null ? {_symbolId!} : {},
              onSelected: (symbol) => setState(() {
                _symbolId = symbol.id;
                _symbolUrl = symbol.imageUrl;
                // Auto-fill label if blank
                if (_labelController.text.trim().isEmpty) {
                  _labelController.text = symbol.label;
                }
              }),
            ),
            const SizedBox(height: 20),

            // ── Background colour ─────────────────────────────────────────────
            const _SectionLabel('Colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: FitzgeraldColors.presets.map((color) {
                final selected = _bgColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _bgColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Action ────────────────────────────────────────────────────────
            const _SectionLabel('Action'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _actionType,
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'speak', child: Text('Speak label')),
                DropdownMenuItem(
                    value: 'navigate', child: Text('Go to board')),
                DropdownMenuItem(
                    value: 'back', child: Text('Go back')),
                DropdownMenuItem(
                    value: 'clear', child: Text('Clear sentence')),
                DropdownMenuItem(
                    value: 'backspace',
                    child: Text('Remove last word')),
              ],
              onChanged: (v) =>
                  setState(() => _actionType = v ?? 'speak'),
            ),

            // Speak text override — only relevant for 'speak' action
            if (_actionType == 'speak') ...[
              const SizedBox(height: 16),
              const _SectionLabel('Speak text (optional)'),
              const SizedBox(height: 4),
              Text(
                'Override what gets spoken. Leave blank to use the label.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _speakController,
                decoration: InputDecoration(
                  hintText: _labelController.text.trim().isNotEmpty
                      ? _labelController.text.trim()
                      : 'Same as label',
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── Save ──────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isNew ? 'Add Cell' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Colors.black54,
      ),
    );
  }
}
