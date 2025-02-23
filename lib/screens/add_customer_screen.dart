import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truthy_wifi_manager/providers/customer_provider.dart'
    show customerProvider;

import '../database/models/customer.dart';
import '../database/models/plan.dart';
import '../database/models/referral_stats.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/subscription_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _referralCodeController = TextEditingController();
  PlanType _selectedPlan = PlanType.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter contact info';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referralCodeController,
              decoration: const InputDecoration(
                labelText: 'Referral Code (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlanType>(
              value: _selectedPlan,
              decoration: const InputDecoration(
                labelText: 'Plan',
                border: OutlineInputBorder(),
              ),
              items: PlanType.values.map((plan) {
                return DropdownMenuItem(
                  value: plan,
                  child: Text(plan.name),
                );
              }).toList(),
              onChanged: (PlanType? value) {
                if (value != null) {
                  setState(() {
                    _selectedPlan = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCustomer,
              child: const Text('Save Customer'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final customer = Customer(
        name: _nameController.text,
        contact: _contactController.text,
        isActive: true,
        wifiName: Customer.generateWifiName(_nameController.text),
        currentPassword: _generatePassword(),
        subscriptionStart: DateTime.now(),
        subscriptionEnd: _calculateEndDate(),
        planType: _selectedPlan,
        referredBy: _referralCodeController.text.isNotEmpty
            ? await _getCustomerIdByReferralCode(_referralCodeController.text)
            : null,
        
      );

      try {
        await ref.read(databaseProvider).saveCustomer(customer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer saved successfully')),
          );
          Navigator.pop(context);
          ref.invalidate(activeCustomersProvider);
          // Apply referral reward if applicable
          if (customer.referredBy != null) {
            await _applyReferralReward(customer.referredBy!, customer);
          }
        }

        ref.invalidate(activeCustomersProvider);
        ref.invalidate(databaseProvider);
        ref.invalidate(customerProvider);
        ref.invalidate(expiringSubscriptionsProvider);
        ref.invalidate(notificationSchedulerProvider);
      } catch (e, stackTrace) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
            // Suggested code may be subject to a license. Learn more: ~LicenseLog:2261690070.
          ).showSnackBar(
            SnackBar(
              content: SelectableText(
                'Error saving customer: $e | $stackTrace',
              ),
              duration: Duration(minutes: 2),
            ),
          );
        }
      }
    }
  }

  Future<String?> _getCustomerIdByReferralCode(String referralCode) async {
    final snapshot = await ref
        .read(databaseProvider)
        .firestore
        .collection(
            ref.read(databaseProvider).getUserCollectionPath('customers'))
        .where('referralCode', isEqualTo: referralCode)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.id;
  }

  Future<void> _applyReferralReward(
      String referrerId, Customer newCustomer) async {
    final database = ref.read(databaseProvider);
    final referrerDoc = await database.firestore
        .collection(database.getUserCollectionPath('customers'))
        .doc(referrerId)
        .get();

    if (!referrerDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referrer not found.')),
        );
      }
      return;
    }

    final referrer = Customer.fromJson(referrerDoc.id, referrerDoc.data()!);
    if (!referrer.isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referrer is inactive.')),
        );
      }
      return;
    }

    final rewardDuration =
        _calculateReferralReward(referrer.planType, newCustomer.planType);
    referrer.subscriptionEnd = referrer.subscriptionEnd.add(rewardDuration);
    referrer.referralRewardApplied = DateTime.now();

    final referralStats = ReferralStats.fromDuration(
      referrerId: referrerId,
      referredCustomerId: newCustomer.id,
      referralDate: DateTime.now(),
      rewardDuration: rewardDuration,
    );

    try {
      // Use a batch to ensure atomic updates
      final batch = database.firestore.batch();
      batch.set(
        database.firestore
            .collection(database.getUserCollectionPath('customers'))
            .doc(referrer.id),
        referrer.toJson(),
      );
      batch.set(
        database.firestore
            .collection(database.getUserCollectionPath('referral_stats'))
            .doc(referralStats.id),
        referralStats.toJson(),
      );
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Referral reward applied: ${referrer.name} gets ${rewardDuration.inDays} days free!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply referral reward: $e')),
        );
      }
    }
  }

  Duration _calculateReferralReward(
    PlanType referrerPlan,
    PlanType newCustomerPlan,
  ) {
    // Define referral rewards based on plans
    if (newCustomerPlan == PlanType.monthly) {
      return const Duration(days: 7); // 7 days free for monthly plan referral
    } else if (newCustomerPlan == PlanType.weekly) {
      return const Duration(days: 3); // 3 days free for weekly plan referral
    } else {
      return const Duration(days: 1); // 1 day free for daily plan referral
    }
  }

  String _generatePassword() {
    // Implement your password generation logic here
    return 'temp-pass-${Random().nextInt(9999)}';
  }

  DateTime _calculateEndDate() {
    switch (_selectedPlan) {
      case PlanType.daily:
        return DateTime.now().add(const Duration(days: 1));
      case PlanType.weekly:
        return DateTime.now().add(const Duration(days: 7));
      case PlanType.monthly:
        return DateTime.now().add(const Duration(days: 30));
    }
  }
}
