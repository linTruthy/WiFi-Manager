import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/billing_cycle.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/referral_stats.dart';

class DatabaseRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String getUserCollectionPath(String collection) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return 'users/${user.uid}/$collection';
  }

  // Customer Operations
  Future<void> saveCustomer(Customer customer) async {
    final collectionPath = getUserCollectionPath('customers');
    if (customer.id.isEmpty) {
      // New customer
      final docRef = firestore.collection(collectionPath).doc();
      customer.id = docRef.id;
      await docRef.set(customer.toJson());
    } else {
      // Update existing customer
      await firestore
          .collection(collectionPath)
          .doc(customer.id)
          .set(customer.toJson());
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    await firestore
        .collection(getUserCollectionPath('customers'))
        .doc(customerId)
        .delete();
  }

  Future<List<Customer>> getActiveCustomers() async {
    final snapshot = await firestore
        .collection(getUserCollectionPath('customers'))
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => Customer.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<List<Customer>> getInactiveCustomers() async {
    final snapshot = await firestore
        .collection(getUserCollectionPath('customers'))
        .where('isActive', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => Customer.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<void> deleteCustomerWithData(
      String customerId, bool deleteAssociatedData) async {
    final batch = firestore.batch();
    final customerRef = firestore
        .collection(getUserCollectionPath('customers'))
        .doc(customerId);
    batch.delete(customerRef);

    if (deleteAssociatedData) {
      final paymentsSnapshot = await firestore
          .collection(getUserCollectionPath('payments'))
          .where('customerId', isEqualTo: customerId)
          .get();
      for (final doc in paymentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final referralStatsSnapshot = await firestore
          .collection(getUserCollectionPath('referral_stats'))
          .where('referrerId', isEqualTo: customerId)
          .get();
      for (final doc in referralStatsSnapshot.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  // Payment Operations
  Future<void> savePayment(Payment payment) async {
    final collectionPath = getUserCollectionPath('payments');
    if (payment.id.isEmpty) {
      final docRef = firestore.collection(collectionPath).doc();
      payment.id = docRef.id;
      await docRef.set(payment.toJson());
    } else {
      await firestore
          .collection(collectionPath)
          .doc(payment.id)
          .set(payment.toJson());
    }
  }

  Future<void> deletePayment(String paymentId) async {
    await firestore
        .collection(getUserCollectionPath('payments'))
        .doc(paymentId)
        .delete();
  }

  Future<List<Payment>> getRecentPayments() async {
    final snapshot = await firestore
        .collection(getUserCollectionPath('payments'))
        .where('paymentDate',
            isGreaterThan: DateTime.now()
                .subtract(const Duration(days: 60))
                .toIso8601String())
        .get();
    return snapshot.docs
        .map((doc) => Payment.fromJson(doc.id, doc.data()))
        .toList();
  }

  // Referral Stats Operations
  Future<void> saveReferralStats(ReferralStats referralStats) async {
    final collectionPath = getUserCollectionPath('referral_stats');
    if (referralStats.id.isEmpty) {
      final docRef = firestore.collection(collectionPath).doc();
      referralStats.id = docRef.id;
      await docRef.set(referralStats.toJson());
    } else {
      await firestore
          .collection(collectionPath)
          .doc(referralStats.id)
          .set(referralStats.toJson());
    }
  }

  Future<List<ReferralStats>> getReferralStats(String referrerId) async {
    final snapshot = await firestore
        .collection(getUserCollectionPath('referral_stats'))
        .where('referrerId', isEqualTo: referrerId)
        .get();
    return snapshot.docs
        .map((doc) => ReferralStats.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<int> getTotalReferrals(String referrerId) async {
    final snapshot = await firestore
        .collection(getUserCollectionPath('referral_stats'))
        .where('referrerId', isEqualTo: referrerId)
        .get();
    return snapshot.docs.length;
  }

  Future<void> saveBillingCycle(BillingCycle cycle) async {
    final collectionPath = getUserCollectionPath('billing_cycles');
    if (cycle.id.isEmpty) {
      final docRef = firestore.collection(collectionPath).doc();
      cycle.id = docRef.id;
      await docRef.set(cycle.toJson());
    } else {
      await firestore
          .collection(collectionPath)
          .doc(cycle.id)
          .set(cycle.toJson());
    }
  }
Future<List<BillingCycle>> getBillingCycles() async {
  final snapshot = await firestore.collection(getUserCollectionPath('billing_cycles')).get();
  return snapshot.docs.map((doc) => BillingCycle.fromJson(doc.id, doc.data())).toList();
}
  Future<Duration> getTotalRewardDuration(String referrerId) async {
    try {
      final referralStats = await getReferralStats(referrerId);
      return referralStats.fold<Duration>(
        Duration.zero,
        (Duration total, ReferralStats referral) =>
            total + Duration(milliseconds: referral.rewardDurationMillis),
      );
    } catch (e) {
      print('Error calculating total reward duration: $e');
      return Duration.zero;
    }
  }

  // Other Methods
  Future<double> calculateActiveCustomerTrend() async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);

    final currentMonthSnapshot = await firestore
        .collection(getUserCollectionPath('customers'))
        .where('isActive', isEqualTo: true)
        .where('subscriptionStart',
            isLessThan: currentMonthStart.toIso8601String())
        .get();
    final previousMonthSnapshot = await firestore
        .collection(getUserCollectionPath('customers'))
        .where('isActive', isEqualTo: true)
        .where('subscriptionStart',
            isLessThan: previousMonthStart.toIso8601String())
        .get();

    final currentCount = currentMonthSnapshot.docs.length;
    final previousCount = previousMonthSnapshot.docs.length;
    return previousCount == 0
        ? 0.0
        : ((currentCount - previousCount) / previousCount) * 100;
  }

  Future<List<Customer>> getExpiringCustomers() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final snapshot = await firestore
        .collection(getUserCollectionPath('customers'))
        .where('isActive', isEqualTo: true)
        .where('subscriptionEnd', isLessThan: tomorrow.toIso8601String())
        .get();
    return snapshot.docs
        .map((doc) => Customer.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<void> activateCustomer(String customerId) async {
    await firestore
        .collection(getUserCollectionPath('customers'))
        .doc(customerId)
        .update({'isActive': true});
  }

  Future<void> deleteAllRecords() async {
    final batch = firestore.batch();
    final customerDocs =
        await firestore.collection(getUserCollectionPath('customers')).get();
    final paymentDocs =
        await firestore.collection(getUserCollectionPath('payments')).get();
    final referralDocs = await firestore
        .collection(getUserCollectionPath('referral_stats'))
        .get();

    for (final doc in customerDocs.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in paymentDocs.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in referralDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
