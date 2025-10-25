import 'package:flutter/material.dart';
import '../models/lift.dart';

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

  @override
  void initState() {
    super.initState();
    final lift = widget.lift;

    nameController = TextEditingController(text: lift?.name ?? '');
    strengthWeightController = TextEditingController(
      text: lift?.strengthPR.weight.toString() ?? '',
    );
    strengthRepsController = TextEditingController(
      text: lift?.strengthPR.reps.toString() ?? '',
    );
    enduranceWeightController = TextEditingController(
      text: lift?.endurancePR.weight.toString() ?? '',
    );
    enduranceRepsController = TextEditingController(
      text: lift?.endurancePR.reps.toString() ?? '',
    );
    notesController = TextEditingController(text: lift?.notes ?? '');
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

  void saveLift() {
    if (_formKey.currentState!.validate()) {
      // If the name is locked (pinned lift), force it to stay what it was
      final effectiveName = widget.lockName && widget.lift != null
          ? widget.lift!.name
          : nameController.text;

      final newLift = Lift(
        name: effectiveName,
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
                  // if locked, make it look disabled-ish
                  suffixIcon: widget.lockName
                      ? const Tooltip(
                          message:
                              "Core lifts can't be renamed",
                          child: Icon(
                            Icons.lock,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
                readOnly: widget.lockName,
                enabled: !widget.lockName,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
                },
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
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
