// ============================================================
// editor_screen.dart — Caregiver board editing mode
//
// Entry: tapping ✏️ in CommunicationScreen.
// PIN gate on entry — first visit sets a PIN, later visits verify.
// Grid mirrors the board layout; each cell (filled or empty)
// opens a CellEditorSheet on tap.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/app_theme.dart';
import '../../main.dart';
import '../../models/database.dart';
import 'cell_editor_sheet.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final Board board;
  final ChildProfile profile;

  const EditorScreen(
      {super.key, required this.board, required this.profile});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    // Run after first frame so context is ready for dialogs.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPin());
  }

  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'editor_pin';

  Future<void> _checkPin() async {
    final stored = await _storage.read(key: _pinKey);
    if (!mounted) return;

    final ok = stored == null
        ? await _showSetPin()
        : await _showVerifyPin(stored);

    if (ok && mounted) {
      setState(() => _unlocked = true);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _showSetPin() async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SetPinDialog(),
    );
    if (pin != null) {
      await _storage.write(key: _pinKey, value: pin);
      return true;
    }
    return false;
  }

  Future<bool> _showVerifyPin(String stored) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerifyPinDialog(storedPin: stored),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.editModeBanner,
        foregroundColor: AppColors.editModeBannerText,
        iconTheme:
            const IconThemeData(color: AppColors.editModeBannerText),
        title: const Text(
          '✏️ Edit Mode',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.editModeBannerText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _unlocked
          ? SafeArea(
              child: StreamBuilder<List<BoardCell>>(
                stream: db.watchCellsForBoard(widget.board.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  return _EditableGrid(
                    cells: snapshot.data!,
                    board: widget.board,
                    db: db,
                  );
                },
              ),
            )
          : const SizedBox.shrink(), // PIN dialog is showing
    );
  }
}

// ─── Editable Grid ─────────────────────────────────────────────────────────

class _EditableGrid extends StatelessWidget {
  final List<BoardCell> cells;
  final Board board;
  final AppDatabase db;

  const _EditableGrid({
    required this.cells,
    required this.board,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final cellMap = {
      for (final c in cells) '${c.rowIndex}_${c.colIndex}': c,
    };

    return Column(
      children: [
        // Hint banner
        Container(
          width: double.infinity,
          color: AppColors.editModeBanner,
          padding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: const Text(
            'Tap a cell to edit · Tap empty slots to add',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.editModeBannerText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: board.gridColumns,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: board.gridRows * board.gridColumns,
              itemBuilder: (context, index) {
                final row = index ~/ board.gridColumns;
                final col = index % board.gridColumns;
                return _EditableCell(
                  cell: cellMap['${row}_$col'],
                  row: row,
                  col: col,
                  board: board,
                  db: db,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Editable Cell ──────────────────────────────────────────────────────────

class _EditableCell extends StatelessWidget {
  final BoardCell? cell;
  final int row;
  final int col;
  final Board board;
  final AppDatabase db;

  const _EditableCell({
    required this.cell,
    required this.row,
    required this.col,
    required this.board,
    required this.db,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  void _openEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CellEditorSheet(
        cell: cell,
        row: row,
        col: col,
        boardId: board.id,
        db: db,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cell == null) {
      return GestureDetector(
        onTap: () => _openEditor(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.black26, size: 32),
          ),
        ),
      );
    }

    final bgColor = _parseColor(cell!.backgroundColor);
    final textColor = _parseColor(cell!.textColor);

    return GestureDetector(
      onTap: () => _openEditor(context),
      child: Stack(
        children: [
          // Cell body
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: cell!.symbolUrl != null
                        ? Image.network(
                            cell!.symbolUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_outlined,
                              color: textColor.withValues(alpha:0.5),
                              size: 28,
                            ),
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: textColor.withValues(alpha:0.4),
                            size: 28,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Text(
                    cell!.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: cell!.fontSize.toDouble(),
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Edit badge
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PIN Dialogs ────────────────────────────────────────────────────────────

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin1.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != _pin2.text.trim()) {
      setState(() => _error = "PINs don't match");
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Edit Mode PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a 4-digit PIN so children can\'t accidentally edit the board.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pin1,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm PIN',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Set PIN'),
        ),
      ],
    );
  }
}

class _VerifyPinDialog extends StatefulWidget {
  final String storedPin;
  const _VerifyPinDialog({required this.storedPin});

  @override
  State<_VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<_VerifyPinDialog> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() == widget.storedPin) {
      Navigator.pop(context, true);
    } else {
      _controller.clear();
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Mode PIN'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Enter PIN',
          counterText: '',
          errorText: _wrong ? 'Incorrect PIN' : null,
        ),
        onChanged: (_) => setState(() => _wrong = false),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
