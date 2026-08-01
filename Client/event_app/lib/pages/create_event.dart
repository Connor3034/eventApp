import 'package:flutter/material.dart';

class CreateEvent extends StatefulWidget {
  const CreateEvent({super.key});

  @override
  State<CreateEvent> createState() => _CreateEventState();
}

class _CreateEventState extends State<CreateEvent> {
  // GlobalKey needed to manage form state and validation
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final _dateController = TextEditingController();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context,
     firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
  );

  if(picked != null) {
    setState(() {
      _selectedDate = picked;
      _dateController.text =
      '${picked.day}/${picked.month}/${picked.year}';
    });
  }

  }

  @override
void dispose() {
  _dateController.dispose();
  super.dispose();
}  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView( // Prevents keyboard overflow
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Event name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Event Date',
                suffixIcon: Icon(Icons.calendar_today_outlined),              
                 ),
                 onTap: _pickDate,
                 validator: (value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                 },

              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () {
                if (_formKey.currentState!.validate()) {
                  //submit event
                }
              } , child: const Text ('Create Event'),
              ),
                
    
            ],
          ),
        ),
      ),
    );
  }
}