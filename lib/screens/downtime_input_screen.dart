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

  final Map<String, bool> _selectedCustomers = {};
  bool _isLoading = false;
  bool _isCompensationEnabled = true;

  @override
  void initState() {
    super.initState();
    _startDateTime = DateTime.now().subtract(const Duration(hours: 1));
    _endDateTime = DateTime.now();
    _loadActiveCustomers();
  }

  Future<void> _loadActiveCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final database = ref.read(databaseProvider);
      final customers = await database.getActiveCustomers();

      setState(() {
        for (var customer in customers) {
          _selectedCustomers[customer.id] = true; // Select all by default
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load customers: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          _buildDateTimeField(
                            label: 'Start Time',
                            value: _startDateTime,
                            onSelected: (dateTime) =>
                                setState(() => _startDateTime = dateTime),
                          ),
                          const SizedBox(height: 8),
                          _buildDateTimeField(
                            label: 'End Time',
                            value: _endDateTime,
                            onSelected: (dateTime) =>
                                setState(() => _endDateTime = dateTime),
                          ),
                          const SizedBox(height: 8),
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
                              validator: (value) => value!.isEmpty
                                  ? 'Please specify the reason'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (duration != null)
                            Semantics(
                              label:
                                  'Downtime duration: ${_formatDuration(duration)}',
                              child: Text(
                                'Duration: ${_formatDuration(duration)}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Compensate affected customers'),
                            subtitle: const Text(
                                'Extend subscription end dates by the downtime duration'),
                            value: _isCompensationEnabled,
                            onChanged: (value) {
                              setState(() {
                                _isCompensationEnabled = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Affected Customers',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildCustomerCheckboxList(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _selectAll,
                                child: const Text('Select All'),
                              ),
                              TextButton(
                                onPressed: _deselectAll,
                                child: const Text('Deselect All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: 'Save downtime record',
                            child: ElevatedButton(
                              onPressed: _isFormValid() ? _saveDowntime : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: database.firestore
                        .collection(
                            database.getUserCollectionPath('downtime_logs'))
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
                          final durationHours =
                              downtime['durationHours'] as num;
                          final affectedCustomers =
                              (downtime['affectedCustomers'] as List<dynamic>)
                                  .cast<String>();
                          return ExpansionTile(
                            title: Text(
                              'Downtime: ${durationHours.toStringAsFixed(1)} hours on ${DateFormat('MMM d, y - h:mm a').format(timestamp)}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Affected Users: ${affectedCustomers.length}'),
                                Text(
                                    'Reason: ${downtime['reason'] ?? 'Not specified'}'),
                                if (downtime['compensationApplied'] == true)
                                  const Text(
                                    'Compensation applied',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start: ${DateFormat('MMM d, y - h:mm a').format(DateTime.parse(downtime['startTime']))}',
                                    ),
                                    Text(
                                      'End: ${DateFormat('MMM d, y - h:mm a').format(DateTime.parse(downtime['endTime']))}',
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Affected Customers:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    ...affectedCustomers
                                        .map((customerId) =>
                                            FutureBuilder<DocumentSnapshot>(
                                              future: database.firestore
                                                  .collection(database
                                                      .getUserCollectionPath(
                                                          'customers'))
                                                  .doc(customerId)
                                                  .get(),
                                              builder:
                                                  (context, customerSnapshot) {
                                                if (!customerSnapshot.hasData) {
                                                  return const Text(
                                                      'Loading...');
                                                }
                                                final customerData =
                                                    customerSnapshot.data!
                                                            .data()
                                                        as Map<String,
                                                            dynamic>?;
                                                return Text(customerData?[
                                                        'name'] ??
                                                    'Unknown Customer (ID: $customerId)');
                                              },
                                            ))
                                        .toList(),
                                  ],
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

  Widget _buildCustomerCheckboxList() {
    if (_selectedCustomers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No active customers found'),
        ),
      );
    }

    final database = ref.read(databaseProvider);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _selectedCustomers.length,
        itemBuilder: (context, index) {
          final customerId = _selectedCustomers.keys.elementAt(index);
          return FutureBuilder<DocumentSnapshot>(
            future: database.firestore
                .collection(database.getUserCollectionPath('customers'))
                .doc(customerId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  title: Text('Loading...'),
                );
              }

              final customerData =
                  snapshot.data!.data() as Map<String, dynamic>?;
              final customerName = customerData?['name'] ?? 'Unknown Customer';

              return CheckboxListTile(
                title: Text(customerName),
                subtitle: Text('ID: $customerId'),
                value: _selectedCustomers[customerId],
                onChanged: (value) {
                  setState(() {
                    _selectedCustomers[customerId] = value ?? false;
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  void _selectAll() {
    setState(() {
      for (var key in _selectedCustomers.keys) {
        _selectedCustomers[key] = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (var key in _selectedCustomers.keys) {
        _selectedCustomers[key] = false;
      }
    });
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
        (_endDateTime!.isAfter(_startDateTime!)) &&
        _selectedCustomers.values.any((selected) => selected);
  }

  Future<void> _saveDowntime() async {
    setState(() {
      _isLoading = true;
    });

    final database = ref.read(databaseProvider);
    final now = DateTime.now();
    final duration = _calculateDuration()!;
    final durationHours = duration.inMinutes / 60.0;

    // Get selected customer IDs
    final affectedCustomerIds = _selectedCustomers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final downtimeData = {
      'startTime': _startDateTime!.toIso8601String(),
      'endTime': _endDateTime!.toIso8601String(),
      'reason': _reason == 'Other' ? _reasonController.text : _reason,
      'durationHours': durationHours,
      'durationMinutes': duration.inMinutes,
      'affectedCustomers': affectedCustomerIds,
      'timestamp': now.toIso8601String(),
      'compensationApplied': _isCompensationEnabled,
    };

    try {
      // Save downtime record
      final downtimeRef = await database.firestore
          .collection(database.getUserCollectionPath('downtime_logs'))
          .add(downtimeData);

      // Apply compensation if enabled
      if (_isCompensationEnabled && affectedCustomerIds.isNotEmpty) {
        await _applyCompensation(affectedCustomerIds, duration);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downtime recorded successfully${_isCompensationEnabled ? ' and compensation applied' : ''}'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the form
      setState(() {
        _startDateTime = DateTime.now().subtract(const Duration(hours: 1));
        _endDateTime = DateTime.now();
        _reason = null;
        _reasonController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _applyCompensation(
      List<String> customerIds, Duration downtimeDuration) async {
    final database = ref.read(databaseProvider);
    final batch = database.firestore.batch();

    for (final customerId in customerIds) {
      final customerRef = database.firestore
          .collection(database.getUserCollectionPath('customers'))
          .doc(customerId);

      final customerDoc = await customerRef.get();
      if (!customerDoc.exists) continue;

      final customerData = customerDoc.data()!;
      if (customerData['isActive'] != true) continue;

      final subscriptionEnd = DateTime.parse(customerData['subscriptionEnd']);
      final newSubscriptionEnd = subscriptionEnd.add(downtimeDuration);

      batch.update(customerRef, {
        'subscriptionEnd': newSubscriptionEnd.toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit();
  }
}
