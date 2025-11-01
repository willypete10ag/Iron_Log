import 'package:flutter/material.dart';
import '../models/lift.dart';
import '../utils/lift_normalizer.dart'; // toTitleCase()
import '../data/canonical_lifts.dart';  // access canonicalLifts

class AddEditLiftView extends StatefulWidget {
  final Lift? lift;
  final bool lockName;
  final Function(Lift) onSave;

  const AddEditLiftView({
    super.key,
    this.lift,
    this.lockName = false,
    required this.onSave,
  });

  @override
  State<AddEditLiftView> createState() => _AddEditLiftViewState();
}

class _AddEditLiftViewState extends State<AddEditLiftView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController strengthWeightController;
  late TextEditingController strengthRepsController;
  late TextEditingController enduranceWeightController;
  late TextEditingController enduranceRepsController;
  late TextEditingController notesController;

  // Track original values to decide whether to prompt
  late final String _originalNameKey;
  late final String? _originalCanonicalId;

  @override
  void initState() {
    super.initState();
    final lift = widget.lift;

    nameController = TextEditingController(text: lift?.name ?? '');
    strengthWeightController =
        TextEditingController(text: lift?.strengthPR.weight.toString() ?? '');
    strengthRepsController =
        TextEditingController(text: lift?.strengthPR.reps.toString() ?? '');
    enduranceWeightController =
        TextEditingController(text: lift?.endurancePR.weight.toString() ?? '');
    enduranceRepsController =
        TextEditingController(text: lift?.endurancePR.reps.toString() ?? '');
    notesController = TextEditingController(text: lift?.notes ?? '');

    _originalNameKey = _normalizeKey(lift?.name ?? '');
    _originalCanonicalId = lift?.canonicalId;
  }

  @override
  void dispose() {
    nameController.dispose();
    strengthWeightController.dispose();
    strengthRepsController.dispose();
    enduranceWeightController.dispose();
    enduranceRepsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // --- Multi-suggestion logic (self-contained here) ---

  String _normalizeKey(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\u2190-\u21FF]'), ' ') // arrows, etc.
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')      // punctuation → space
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<_Candidate> _suggestCanonicalCandidates(String raw) {
    final key = _normalizeKey(raw);
    if (key.isEmpty) return const [];

    final List<_ScoredCandidate> scored = [];

    for (final c in canonicalLifts) {
      final disp = _normalizeKey(c.displayName);
      final aliases = c.aliases.map(_normalizeKey).toList();

      // Exact match priority (best)
      if (disp == key || aliases.contains(key)) {
        scored.add(_ScoredCandidate(
          candidate: _Candidate(id: c.id, displayName: c.displayName),
          score: 0,
        ));
        continue;
      }

      // Containment (good)
      if (disp.contains(key) ||
          key.contains(disp) ||
          aliases.any((a) => a.contains(key) || key.contains(a))) {
        scored.add(_ScoredCandidate(
          candidate: _Candidate(id: c.id, displayName: c.displayName),
          score: 1,
        ));
        continue;
      }

      // Word-overlap (okay)
      final keyWords = key.split(' ').toSet()..removeWhere((w) => w.isEmpty);
      if (keyWords.isEmpty) continue;

      final dispWords = disp.split(' ').toSet();
      final aliasWords = aliases.expand((a) => a.split(' ')).toSet();

      final overlap =
          keyWords.intersection(dispWords).length +
          keyWords.intersection(aliasWords).length;

      if (overlap >= 2) {
        scored.add(_ScoredCandidate(
          candidate: _Candidate(id: c.id, displayName: c.displayName),
          score: 2,
        ));
      }
    }

    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return a.candidate.displayName.compareTo(b.candidate.displayName);
    });

    // limit to a handful for UX
    return scored.map((s) => s.candidate).take(6).toList();
  }

  Future<void> saveLift() async {
    if (!_formKey.currentState!.validate()) return;

    final rawName = nameController.text.trim();
    final currentNameKey = _normalizeKey(rawName);
    final isEditing = widget.lift != null;
    final alreadyCanonical = (_originalCanonicalId != null && _originalCanonicalId!.isNotEmpty);
    final nameChanged = currentNameKey != _originalNameKey;

    // Only prompt if:
    // - creating a brand new lift, OR
    // - editing and (the name changed OR it wasn't canonical yet)
    final shouldSuggest = !isEditing || nameChanged || !alreadyCanonical;

    if (shouldSuggest) {
      final suggestions = _suggestCanonicalCandidates(rawName);

      if (suggestions.length > 1) {
        final chosen = await _showSuggestionPicker(suggestions);
        if (chosen != null) {
          _saveLiftInternal(
            effectiveName: chosen.displayName,
            canonicalId: chosen.id,
          );
          return;
        }
        // Keep typed name; do NOT silently canonicalize
        _saveLiftInternal(
          effectiveName: toTitleCase(rawName),
          canonicalId: isEditing ? _originalCanonicalId : null,
        );
        return;
      }

      if (suggestions.length == 1) {
        final s = suggestions.first;

        // If we’re editing and user didn't change the name AND it’s already canonical to this ID, skip dialog
        if (isEditing && !nameChanged && _originalCanonicalId == s.id) {
          _saveLiftInternal(
            effectiveName: widget.lift!.name,
            canonicalId: _originalCanonicalId,
          );
          return;
        }

        // Otherwise, confirm
        final userChoice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Recognized Lift'),
            content: Text('Did you mean "${s.displayName}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep My Name'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use Suggested'),
              ),
            ],
          ),
        );

        if (userChoice == true) {
          _saveLiftInternal(
            effectiveName: s.displayName,
            canonicalId: s.id,
          );
          return;
        }

        // Keep typed name; preserve old canonicalId if we had one
        _saveLiftInternal(
          effectiveName: toTitleCase(rawName),
          canonicalId: isEditing ? _originalCanonicalId : null,
        );
        return;
      }
    }

    // No suggestions (or we decided not to prompt)
    _saveLiftInternal(
      effectiveName: isEditing && !nameChanged ? widget.lift!.name : toTitleCase(rawName),
      canonicalId: isEditing ? _originalCanonicalId : null,
    );
  }

  Future<_Candidate?> _showSuggestionPicker(List<_Candidate> candidates) async {
    return showModalBottomSheet<_Candidate>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'We found multiple matches',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Pick the one you meant, or keep your name.'),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = candidates[i];
                    return ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: Text(c.displayName),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Keep My Name'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveLiftInternal({
    required String effectiveName,
    required String? canonicalId,
  }) {
    final newLift = Lift(
      name: effectiveName,
      canonicalId: canonicalId,
      strengthPR: PRSet(
        weight: int.tryParse(strengthWeightController.text) ?? 0,
        reps: int.tryParse(strengthRepsController.text) ?? 0,
      ),
      endurancePR: PRSet(
        weight: int.tryParse(enduranceWeightController.text) ?? 0,
        reps: int.tryParse(enduranceRepsController.text) ?? 0,
      ),
      notes: notesController.text,
      lastUpdated: DateTime.now(),
    );

    widget.onSave(newLift);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lift != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Lift' : 'Add Lift'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveLift,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // LIFT NAME
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Lift Name',
                  suffixIcon: widget.lockName
                      ? const Tooltip(
                          message: "This lift's name is locked",
                          child: Icon(Icons.lock, color: Colors.grey),
                        )
                      : null,
                ),
                readOnly: widget.lockName,
                enabled: !widget.lockName,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter a name' : null,
              ),

              const SizedBox(height: 24),

              // STRENGTH PR
              const Text(
                'Strength PR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: strengthWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        suffixText: 'lbs',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('×', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: strengthRepsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        suffixText: 'reps',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ENDURANCE PR
              const Text(
                'Endurance PR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: enduranceWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        suffixText: 'lbs',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('×', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: enduranceRepsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        suffixText: 'reps',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // NOTES
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Candidate {
  final String id;
  final String displayName;
  const _Candidate({required this.id, required this.displayName});
}

class _ScoredCandidate {
  final _Candidate candidate;
  final int score; // 0 = best (exact), 1 = contains, 2 = overlap
  _ScoredCandidate({required this.candidate, required this.score});
}
