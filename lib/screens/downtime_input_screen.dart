import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_notification_service.dart';

class DowntimeInputScreen extends ConsumerStatefulWidget {
  const DowntimeInputScreen({super.key});

  @override
  ConsumerState<DowntimeInputScreen> createState() =>
      _DowntimeInputScreenState();
}

class _DowntimeInputScreenState extends ConsumerState<DowntimeInputScreen> {
  final _formKey = GlobalKey<FormState>();
  Duration _downtimeDuration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Downtime')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Form for New Downtime
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Downtime Duration (in hours)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a duration';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _downtimeDuration = Duration(hours: int.parse(value!));
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _applyDowntime,
                    child: const Text('Apply Downtime'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Past Downtimes Section
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
      ),
    );
  }

  Future<void> _applyDowntime() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Downtime'),
          content: Text(
              'Extend all active subscriptions by ${_downtimeDuration.inHours} hours?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final database = ref.read(databaseProvider);

      // Fetch active customers from Firestore
      final snapshot = await database.firestore
          .collection(database.getUserCollectionPath('customers'))
          .where('isActive', isEqualTo: true)
          .get();
      final activeCustomers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();

      // Update each customer's subscription end date
      final batch = database.firestore.batch();
      for (final customer in activeCustomers) {
        customer.subscriptionEnd =
            customer.subscriptionEnd.add(_downtimeDuration);
        batch.set(
          database.firestore
              .collection(database.getUserCollectionPath('customers'))
              .doc(customer.id),
          customer.toJson(),
        );
      }

      // Log downtime event
      final downtimeLog = {
        'durationHours': _downtimeDuration.inHours,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'affectedCustomers': activeCustomers.map((c) => c.id).toList(),
      };
      final logRef = database.firestore
          .collection(database.getUserCollectionPath('downtime_logs'))
          .doc();
      batch.set(logRef, downtimeLog);

      await batch.commit();

      // Schedule notifications for updated customers
      for (final customer in activeCustomers) {
        await SubscriptionNotificationService.scheduleExpirationNotification(
            customer);
        final message =
            'Your subscription has been extended by ${_downtimeDuration.inHours} hours due to downtime.';
        print('Notification sent to ${customer.name}: $message');
      }

      if (mounted) {
        ref.invalidate(activeCustomersProvider);
        ref.invalidate(expiringSubscriptionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downtime applied successfully')),
        );
        Navigator.pop(context);
      }
    }
  }
}
