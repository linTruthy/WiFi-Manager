import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/database_provider.dart';

class DowntimeInputScreen extends ConsumerStatefulWidget {
  const DowntimeInputScreen({super.key});

  @override
  ConsumerState<DowntimeInputScreen> createState() =>
      _DowntimeInputScreenState();
}

class _DowntimeInputScreenState extends ConsumerState<DowntimeInputScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String? _reason;
  final _reasonController = TextEditingController();

  final List<String> _commonReasons = [
    'Power Outage',
    'Network Maintenance',
    'Hardware Failure',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _startDateTime = DateTime.now(); // Pre-fill with current time
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _calculateDuration();
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Downtime'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Start DateTime Picker
                    _buildDateTimeField(
                      label: 'Start Time',
                      value: _startDateTime,
                      onSelected: (dateTime) =>
                          setState(() => _startDateTime = dateTime),
                    ),
                    const SizedBox(height: 8),

                    // End DateTime Picker
                    _buildDateTimeField(
                      label: 'End Time',
                      value: _endDateTime,
                      onSelected: (dateTime) =>
                          setState(() => _endDateTime = dateTime),
                    ),
                    const SizedBox(height: 8),

                    // Reason Dropdown or Text Input
                    DropdownButtonFormField<String>(
                      value: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Downtime',
                        border: OutlineInputBorder(),
                      ),
                      items: _commonReasons.map((reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _reason = value;
                          if (value == 'Other') {
                            _reasonController.clear();
                          } else {
                            _reasonController.text = value ?? '';
                          }
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a reason' : null,
                    ),
                    if (_reason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Specify Reason',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please specify the reason' : null,
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Duration Display
                    if (duration != null)
                      Semantics(
                        label:
                            'Downtime duration: ${_formatDuration(duration)}',
                        child: Text(
                          'Duration: ${_formatDuration(duration)}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Save Button
                    Semantics(
                      label: 'Save downtime record',
                      child: ElevatedButton(
                        onPressed: _isFormValid() ? _saveDowntime : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save Downtime'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Past Downtimes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: database.firestore
                  .collection(database.getUserCollectionPath('downtime_logs'))
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No past downtimes recorded.'));
                }

                final downtimes = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: downtimes.length,
                  itemBuilder: (context, index) {
                    final downtime =
                        downtimes[index].data() as Map<String, dynamic>;
                    final timestamp =
                        DateTime.parse(downtime['timestamp'] as String);
                    final durationHours = downtime['durationHours'] as int;
                    final affectedCustomers =
                        (downtime['affectedCustomers'] as List<dynamic>)
                            .cast<String>();
                    return ExpansionTile(
                      title: Text(
                        'Downtime: $durationHours hours on ${DateFormat('MMM d, y - h:mm a').format(timestamp)}',
                      ),
                      subtitle:
                          Text('Affected Users: ${affectedCustomers.length}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: affectedCustomers
                                .map((customerId) =>
                                    FutureBuilder<DocumentSnapshot>(
                                      future: database.firestore
                                          .collection(
                                              database.getUserCollectionPath(
                                                  'customers'))
                                          .doc(customerId)
                                          .get(),
                                      builder: (context, customerSnapshot) {
                                        if (!customerSnapshot.hasData) {
                                          return const SizedBox.shrink();
                                        }
                                        final customerData =
                                            customerSnapshot.data!.data()
                                                as Map<String, dynamic>?;
                                        return Text(customerData?['name'] ??
                                            'Unknown Customer');
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime? value,
    required Function(DateTime?) onSelected,
  }) {
    return Semantics(
      label: 'Select $label',
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(
          text: value != null
              ? DateFormat('MMM d, y - hh:mm a').format(value)
              : '',
        ),
        validator: (value) => value!.isEmpty ? 'Please select $label' : null,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (date != null) {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
            );
            if (time != null) {
              final dateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              onSelected(dateTime);
            }
          }
        },
      ),
    );
  }

  Duration? _calculateDuration() {
    if (_startDateTime != null && _endDateTime != null) {
      return _endDateTime!.difference(_startDateTime!);
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours hour${hours != 1 ? 's' : ''} $minutes minute${minutes != 1 ? 's' : ''}';
  }

  bool _isFormValid() {
    return _formKey.currentState?.validate() == true &&
        _startDateTime != null &&
        _endDateTime != null &&
        (_reason != null &&
            (_reason != 'Other' || _reasonController.text.isNotEmpty)) &&
        (_endDateTime!.isAfter(_startDateTime!));
  }

  Future<void> _saveDowntime() async {
    final database = ref.read(databaseProvider);
    final downtimeData = {
      'startTime': _startDateTime!.toIso8601String(),
      'endTime': _endDateTime!.toIso8601String(),
      'reason': _reason == 'Other' ? _reasonController.text : _reason,
      'durationMinutes': _calculateDuration()!.inMinutes,
      'loggedAt': DateTime.now().toIso8601String(),
    };

    try {
      await database.firestore
          .collection(database.getUserCollectionPath('downtime'))
          .add(downtimeData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downtime recorded successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }
}
