// ============================================================
// communication_screen.dart — Child-facing AAC board view
//
// Design principles:
//   • Full screen — no distracting chrome in communication mode
//   • Sentence bar always visible at top for built-up phrases
//   • Edit mode button small and unobtrusive (caregiver only)
//   • Grid fills available space — cells sized by constraints
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_theme.dart';
import '../../main.dart';
import '../../models/database.dart';
import '../../services/tts_service.dart';
import '../../widgets/grid/communication_grid.dart';
import '../editor/editor_screen.dart';

class CommunicationScreen extends ConsumerStatefulWidget {
  final ChildProfile profile;
  const CommunicationScreen({super.key, required this.profile});

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen> {
  final List<String> _words = [];
  Board? _homeBoard;
  bool _loading = true;
  // The last spoken word — drives word prediction strip.
  String? _lastLabel;

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _initTts();
  }

  Future<void> _loadBoard() async {
    final db = ref.read(dbProvider);
    final board = await db.getHomeBoardForChild(widget.profile.id);
    if (mounted) {
      setState(() {
        _homeBoard = board;
        _loading = false;
      });
    }
  }

  Future<void> _initTts() async {
    await ref.read(ttsServiceProvider).initialize(
      rate: widget.profile.voiceRate,
      pitch: widget.profile.voicePitch,
      volume: widget.profile.voiceVolume,
      voiceIdentifier: widget.profile.voiceIdentifier,
    );
  }

  void _onCellTapped(BoardCell cell) {
    setState(() {
      switch (cell.actionType) {
        case 'speak':
          _words.add(cell.speakText ?? cell.label);
          _lastLabel = cell.label;
        case 'backspace':
          if (_words.isNotEmpty) _words.removeLast();
          // Keep _lastLabel so predictions stay relevant.
        case 'clear':
          _words.clear();
          _lastLabel = null;
      }
    });
  }

  Future<void> _onPredictionTapped(String word) async {
    final prev = _lastLabel;
    setState(() {
      _words.add(word);
      _lastLabel = word;
    });
    final db = ref.read(dbProvider);
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(word);
    if (prev != null) {
      await db.updatePredictionWeight(widget.profile.id, prev, word);
    }
  }

  Future<void> _speakAll() async {
    if (_words.isEmpty) return;
    await ref.read(ttsServiceProvider).speak(_words.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SentenceBar(
              words: _words,
              onBack: () => Navigator.pop(context),
              onSpeakAll: _speakAll,
              onBackspace: () {
                if (_words.isNotEmpty) {
                  setState(() => _words.removeLast());
                }
              },
              onClear: () => setState(() => _words.clear()),
              onEditMode: () {
                if (_homeBoard != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorScreen(
                        board: _homeBoard!,
                        profile: widget.profile,
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            if (_lastLabel != null)
              _PredictionStrip(
                key: ValueKey(_lastLabel),
                lastLabel: _lastLabel!,
                childId: widget.profile.id,
                db: db,
                onTap: _onPredictionTapped,
              ),
            Expanded(child: _buildGrid(db)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(AppDatabase db) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_homeBoard == null) {
      return _NoBoard(name: widget.profile.name, hasBoard: false);
    }

    return StreamBuilder<List<BoardCell>>(
      stream: db.watchCellsForBoard(_homeBoard!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cells = snapshot.data!;
        if (cells.isEmpty) {
          return _NoBoard(name: widget.profile.name, hasBoard: true);
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: CommunicationGrid(
            cells: cells,
            gridColumns: _homeBoard!.gridColumns,
            gridRows: _homeBoard!.gridRows,
            childId: widget.profile.id,
            db: db,
            accessMethod: widget.profile.accessMethod,
            scanSpeedMs: widget.profile.scanSpeedMs,
            onCellTapped: _onCellTapped,
          ),
        );
      },
    );
  }
}

// ─── Prediction Strip ─────────────────────────────────────────────────────────
// Shown below the sentence bar when a word has been spoken.
// Keyed on lastLabel so it re-fetches whenever the preceding word changes.

class _PredictionStrip extends StatefulWidget {
  final String lastLabel;
  final int childId;
  final AppDatabase db;
  final Future<void> Function(String word) onTap;

  const _PredictionStrip({
    super.key,
    required this.lastLabel,
    required this.childId,
    required this.db,
    required this.onTap,
  });

  @override
  State<_PredictionStrip> createState() => _PredictionStripState();
}

class _PredictionStripState extends State<_PredictionStrip> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.db.getPredictions(widget.childId, widget.lastLabel);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snapshot) {
        final predictions = snapshot.data ?? [];
        if (predictions.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 44,
          color: AppColors.surface,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: predictions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final word = predictions[i];
              return InkWell(
                onTap: () => widget.onTap(word),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryLight, width: 1.5),
                  ),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Sentence Bar ─────────────────────────────────────────────────────────────

class _SentenceBar extends StatelessWidget {
  final List<String> words;
  final VoidCallback onBack;
  final Future<void> Function() onSpeakAll;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEditMode;

  const _SentenceBar({
    required this.words,
    required this.onBack,
    required this.onSpeakAll,
    required this.onBackspace,
    required this.onClear,
    required this.onEditMode,
  });

  @override
  Widget build(BuildContext context) {
    final hasWords = words.isNotEmpty;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          // Home / back button
          IconButton(
            icon: const Icon(Icons.home_outlined),
            color: AppColors.primary,
            tooltip: 'Back to profiles',
            onPressed: onBack,
          ),

          // Sentence display — scrollable, tappable to speak
          Expanded(
            child: GestureDetector(
              onTap: hasWords ? onSpeakAll : null,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: hasWords
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: words.length,
                        separatorBuilder: (_, __) =>
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: VerticalDivider(
                                width: 12,
                                color: Colors.grey.shade300,
                              ),
                            ),
                        itemBuilder: (_, i) => Center(
                          child: Text(
                            words[i],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'Tap symbols to build a sentence',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Speak all — only visible when words present
          if (hasWords)
            IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              color: AppColors.primary,
              tooltip: 'Speak sentence',
              onPressed: onSpeakAll,
            ),

          // Backspace — only visible when words present
          if (hasWords)
            IconButton(
              icon: const Icon(Icons.backspace_outlined),
              color: Colors.grey.shade600,
              tooltip: 'Remove last word',
              onPressed: onBackspace,
            ),

          // Edit mode toggle (caregiver only)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: Colors.grey.shade400,
            tooltip: 'Edit mode (caregiver)',
            onPressed: onEditMode,
          ),
        ],
      ),
    );
  }
}

// ─── No Board Placeholder ─────────────────────────────────────────────────────

class _NoBoard extends StatelessWidget {
  final String name;
  final bool hasBoard; // true = board exists but is empty

  const _NoBoard({required this.name, required this.hasBoard});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              hasBoard
                  ? "$name's board has no symbols yet"
                  : 'No board set up yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the ✏️ edit button above to add symbols.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
