import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_number/phone_number.dart';
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
  // final _contactController = TextEditingController();
  String? _phoneNumber;
  String? _isoCode;
  final _referralCodeController = TextEditingController();
  PlanType _selectedPlan = PlanType.monthly;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Please fill in the details to add a new customer.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Customer name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // TextFormField(
            //   controller: _contactController,
            //   decoration: const InputDecoration(
            //     labelText: 'Contact',
            //     border: OutlineInputBorder(),
            //   ),
            //   validator: (value) {
            //     if (value == null || value.isEmpty) {
            //       return 'Contact information is required';
            //     }
            //     return null;
            //   },
            // ),
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'UG', // Default to Uganda, adjust as needed
              onChanged: (phone) {
                setState(() {
                  _phoneNumber = phone.completeNumber; // E.164 format
                  _isoCode = phone.countryISOCode; // e.g., 'UG', 'US'
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referralCodeController,
              decoration: const InputDecoration(
                labelText: 'Referral Code (Optional)',
                helperText:
                    'Enter a referral code to reward the referrer with free subscription days',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveCustomer,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Customer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // void _saveCustomer() async {
  //   if (_formKey.currentState?.validate() ?? false) {
  //     final customer = Customer(
  //       name: _nameController.text,
  //       contact: _contactController.text,
  //       isActive: true,
  //       wifiName: Customer.generateWifiName(_nameController.text),
  //       currentPassword: Customer.generate(
  //         length: 6,
  //         useSpecialChars: true,
  //         useLowerCase: true,
  //         useNumbers: true,
  //       ),
  //       subscriptionStart: DateTime.now(),
  //       subscriptionEnd: _calculateEndDate(),
  //       planType: _selectedPlan,
  //       referredBy: _referralCodeController.text.isNotEmpty
  //           ? await _getCustomerIdByReferralCode(_referralCodeController.text)
  //           : null,
  //     );

  //     try {
  //       await ref.read(databaseProvider).saveCustomer(customer);
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Customer saved successfully')),
  //         );
  //         Navigator.pop(context);
  //         ref.invalidate(activeCustomersProvider);
  //         // Apply referral reward if applicable
  //         if (customer.referredBy != null) {
  //           await _applyReferralReward(customer.referredBy!, customer);
  //         }
  //       }

  //       ref.invalidate(activeCustomersProvider);
  //       ref.invalidate(databaseProvider);
  //       ref.invalidate(customerProvider);
  //       ref.invalidate(expiringSubscriptionsProvider);
  //       ref.invalidate(notificationSchedulerProvider);
  //     } catch (e, stackTrace) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(
  //           context,
  //           // Suggested code may be subject to a license. Learn more: ~LicenseLog:2261690070.
  //         ).showSnackBar(
  //           SnackBar(
  //             content: SelectableText(
  //               'Error saving customer: $e | $stackTrace',
  //             ),
  //             duration: Duration(minutes: 2),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }
  void _saveCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_phoneNumber == null || _isoCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      final phoneUtil = PhoneNumberUtil();
      final isValid = await phoneUtil.validate(_phoneNumber!, _isoCode!);
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please enter a valid phone number for the selected country')),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final referralCode = _referralCodeController.text;
      String? referrerId;
      if (referralCode.isNotEmpty) {
        referrerId = await _getCustomerIdByReferralCode(referralCode);
        if (referrerId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid referral code. Customer will be added without referral.'),
            ),
          );
        }
      }

      final customer = Customer(
        name: _nameController.text,
        contact: _phoneNumber!,
        isActive: true,
        wifiName: Customer.generateWifiName(_nameController.text),
        currentPassword: Customer.generate(
          length: 6,
          useSpecialChars: true,
          useLowerCase: true,
          useNumbers: true,
        ),
        subscriptionStart: DateTime.now(),
        subscriptionEnd: _calculateEndDate(),
        planType: _selectedPlan,
        referredBy: referrerId,
      );

      try {
        await ref.read(databaseProvider).saveCustomer(customer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer saved successfully')),
          );
          Navigator.pop(context);
          ref.invalidate(activeCustomersProvider);
          if (customer.referredBy != null) {
            await _applyReferralReward(customer.referredBy!, customer);
          }
          // Invalidate dependent providers to refresh data
          ref.invalidate(activeCustomersProvider);
          ref.invalidate(customerProvider);
          ref.invalidate(expiringSubscriptionsProvider);
          ref.invalidate(notificationSchedulerProvider);
        }
      } catch (e, stackTrace) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  SelectableText('Error saving customer: $e | $stackTrace'),
              duration: const Duration(minutes: 2),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
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
