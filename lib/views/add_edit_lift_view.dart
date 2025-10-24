import 'package:flutter/material.dart';
import '../models/lift.dart';

class AddEditLiftView extends StatefulWidget {
  final Lift? lift;
  final Function(Lift) onSave;

  const AddEditLiftView({super.key, this.lift, required this.onSave});

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
    strengthWeightController = TextEditingController(text: lift?.strengthPR.weight.toString() ?? '');
    strengthRepsController = TextEditingController(text: lift?.strengthPR.reps.toString() ?? '');
    enduranceWeightController = TextEditingController(text: lift?.endurancePR.weight.toString() ?? '');
    enduranceRepsController = TextEditingController(text: lift?.endurancePR.reps.toString() ?? '');
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
      final lift = Lift(
        name: nameController.text,
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
      widget.onSave(lift);
      Navigator.pop(context);
    }
  }

  bool get isMainLift {
    final currentName = nameController.text;
    return ['Bench Press', 'Squat', 'Deadlift'].contains(currentName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lift == null ? 'Add Lift' : 'Edit Lift'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveLift,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Lift Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter a name' : null,
                onChanged: (value) => setState(() {}),
              ),

              const SizedBox(height: 16),
              const Text('Strength PR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: strengthWeightController,
                      decoration: const InputDecoration(labelText: 'Weight', suffixText: 'lbs'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('×', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: strengthRepsController,
                      decoration: const InputDecoration(labelText: 'Reps', suffixText: 'reps'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text('Endurance PR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: enduranceWeightController,
                      decoration: const InputDecoration(labelText: 'Weight', suffixText: 'lbs'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('×', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: enduranceRepsController,
                      decoration: const InputDecoration(labelText: 'Reps', suffixText: 'reps'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
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
