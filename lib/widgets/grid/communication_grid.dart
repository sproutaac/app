// ============================================================
// communication_grid.dart — The core child-facing UI
//
// Design principles:
//   • Large, high-contrast tap targets (minimum 60x60dp)
//   • No editing affordances visible in communication mode
//   • Motor planning: cells never move
//   • Switch scanning support built in
//   • Immediate audio feedback on every tap
// ============================================================

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../services/tts_service.dart';

class CommunicationGrid extends ConsumerStatefulWidget {
  final List<BoardCell> cells;
  final int gridColumns;
  final int gridRows;
  final int childId;
  final String accessMethod; // 'touch' | 'switch_single' | 'switch_dual'
  final int scanSpeedMs;
  final AppDatabase db;
  final void Function(BoardCell cell)? onNavigate;
  final void Function(BoardCell cell)? onCellTapped;

  const CommunicationGrid({
    super.key,
    required this.cells,
    required this.gridColumns,
    required this.gridRows,
    required this.childId,
    required this.db,
    this.accessMethod = 'touch',
    this.scanSpeedMs = 1500,
    this.onNavigate,
    this.onCellTapped,
  });

  @override
  ConsumerState<CommunicationGrid> createState() =>
      _CommunicationGridState();
}

class _CommunicationGridState
    extends ConsumerState<CommunicationGrid> {
  // For switch scanning
  int _scanIndex = 0;
  bool _isScanning = false;

  // Last tapped label for prediction context
  String? _lastLabel;

  @override
  void initState() {
    super.initState();
    if (widget.accessMethod != 'touch') {
      _startScanning();
    }
  }

  void _startScanning() {
    _isScanning = true;
    _advanceScan();
  }

  void _advanceScan() {
    if (!_isScanning || !mounted) return;
    Future.delayed(Duration(milliseconds: widget.scanSpeedMs), () {
      if (!mounted) return;
      setState(() {
        _scanIndex = (_scanIndex + 1) % widget.cells.length;
      });
      _advanceScan();
    });
  }

  Future<void> _handleCellTap(BoardCell cell) async {
    final tts = ref.read(ttsServiceProvider);

    // Record usage for prediction model
    await widget.db.recordTap(
      widget.childId,
      cell.id,
      cell.label,
    );

    // Update bigram prediction weights
    if (_lastLabel != null) {
      await widget.db.updatePredictionWeight(
        widget.childId,
        _lastLabel!,
        cell.label,
      );
    }
    _lastLabel = cell.label;

    // Handle action type
    switch (cell.actionType) {
      case 'speak':
        final textToSpeak = cell.speakText ?? cell.label;
        if (textToSpeak.isNotEmpty) {
          await tts.speak(textToSpeak);
        }
        widget.onCellTapped?.call(cell);

      case 'navigate':
        widget.onNavigate?.call(cell);

      case 'back':
        if (Navigator.canPop(context)) Navigator.pop(context);

      case 'clear':
        _lastLabel = null;
        widget.onCellTapped?.call(cell);

      case 'backspace':
        widget.onCellTapped?.call(cell);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build a complete grid with empty cells for unfilled positions
    final Map<String, BoardCell> cellMap = {
      for (final c in widget.cells) '${c.rowIndex}_${c.colIndex}': c
    };

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.gridColumns,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: widget.gridRows * widget.gridColumns,
      itemBuilder: (context, index) {
        final row = index ~/ widget.gridColumns;
        final col = index % widget.gridColumns;
        final cell = cellMap['${row}_$col'];

        if (cell == null || !cell.isVisible) {
          return const SizedBox.shrink();
        }

        final isScanned = widget.accessMethod != 'touch' &&
            _scanIndex < widget.cells.length &&
            widget.cells[_scanIndex].id == cell.id;

        return _CommunicationCell(
          cell: cell,
          isScanned: isScanned,
          onTap: () => _handleCellTap(cell),
        );
      },
    );
  }

  @override
  void dispose() {
    _isScanning = false;
    super.dispose();
  }
}

class _CommunicationCell extends StatefulWidget {
  final BoardCell cell;
  final bool isScanned;
  final VoidCallback onTap;

  const _CommunicationCell({
    required this.cell,
    required this.isScanned,
    required this.onTap,
  });

  @override
  State<_CommunicationCell> createState() => _CommunicationCellState();
}

class _CommunicationCellState extends State<_CommunicationCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeIn),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(widget.cell.backgroundColor);
    final textColor = _parseColor(widget.cell.textColor);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: Semantics(
          label: widget.cell.label,
          button: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: widget.isScanned
                  ? Border.all(color: Colors.yellow, width: 4)
                  : Border.all(color: bgColor.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Symbol image
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: _SymbolImage(cell: widget.cell),
                  ),
                ),
                // Label
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Text(
                    widget.cell.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize:
                          widget.cell.fontSize.toDouble(),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }
}

class _SymbolImage extends StatelessWidget {
  final BoardCell cell;

  const _SymbolImage({required this.cell});

  @override
  Widget build(BuildContext context) {
    // Priority: custom local photo > cached remote > placeholder
    if (cell.customImagePath != null) {
      final file = File(cell.customImagePath!);
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (cell.symbolUrl != null && cell.symbolUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cell.symbolUrl!,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _placeholder(),
        placeholder: (_, __) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white54,
        size: 32,
      ),
    );
  }
}
