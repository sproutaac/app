// ============================================================
// profile_selection_screen.dart
// First screen shown at launch. Shows child profiles.
// Large, friendly, minimal UI — children may use this too.
// ============================================================

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../models/database.dart';
import '../../constants/app_theme.dart';
import '../communication/communication_screen.dart';

class ProfileSelectionScreen extends ConsumerWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // App header
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                children: [
                  Text(
                    '🌱 Sprout',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Who is communicating today?',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Profile grid
            Expanded(
              child: StreamBuilder<List<ChildProfile>>(
                stream: db.watchAllProfiles(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final profiles = snapshot.data ?? [];

                  if (profiles.isEmpty) {
                    return _EmptyState(onAdd: () => _addProfile(context, db));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: profiles.length + 1, // +1 for add button
                    itemBuilder: (context, index) {
                      if (index == profiles.length) {
                        return _AddProfileCard(
                          onTap: () => _addProfile(context, db),
                        );
                      }
                      return _ProfileCard(
                        profile: profiles[index],
                        onTap: () => _selectProfile(
                            context, ref, profiles[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectProfile(
      BuildContext context, WidgetRef ref, ChildProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunicationScreen(profile: profile),
      ),
    );
  }

  void _addProfile(BuildContext context, AppDatabase db) {
    // TODO: Navigate to AddProfileScreen
    showDialog(
      context: context,
      builder: (_) => _QuickAddProfileDialog(db: db),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ChildProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: profile.avatarPath != null
                  ? FileImage(File(profile.avatarPath!)) as ImageProvider
                  : null,
              child: profile.avatarPath == null
                  ? Text(
                      profile.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${profile.gridColumns}×${profile.gridRows} grid',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add Child',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.record_voice_over_outlined,
                size: 80, color: AppColors.primaryLight),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Sprout',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a profile to get started.\nSprout is completely free — always.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create First Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Quick-add dialog for initial profile creation
class _QuickAddProfileDialog extends ConsumerStatefulWidget {
  final AppDatabase db;
  const _QuickAddProfileDialog({required this.db});

  @override
  ConsumerState<_QuickAddProfileDialog> createState() =>
      _QuickAddProfileDialogState();
}

class _QuickAddProfileDialogState
    extends ConsumerState<_QuickAddProfileDialog> {
  final _nameController = TextEditingController();
  int _gridSize = 9; // 3x3 default
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Child Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Child\'s name',
              hintText: 'e.g. Alex',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          const Text('Starting grid size:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 9, label: Text('3×3\n9 cells')),
              ButtonSegment(value: 16, label: Text('4×4\n16 cells')),
              ButtonSegment(value: 25, label: Text('5×5\n25 cells')),
            ],
            selected: {_gridSize},
            onSelectionChanged: (v) =>
                setState(() => _gridSize = v.first),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can change this later.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final cols = _gridSize == 9 ? 3 : _gridSize == 16 ? 4 : 5;

    final profileId = await widget.db.insertProfile(ChildProfilesCompanion.insert(
      name: name,
      gridColumns: Value(cols),
      gridRows: Value(cols),
    ));

    // Create an empty home board so CommunicationScreen has something to stream
    await widget.db.insertBoard(BoardsCompanion.insert(
      childId: profileId,
      name: 'Home Board',
      isHomeBoard: const Value(true),
      gridColumns: Value(cols),
      gridRows: Value(cols),
    ));

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

