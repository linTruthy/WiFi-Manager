// import 'package:flutter/material.dart';

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:wifi_manager/providers/database_provider.dart';
// import 'package:wifi_manager/providers/subscription_provider.dart';
// import 'package:wifi_manager/services/subscription_widget_service.dart';

// class SubscriptionSummaryWidget extends ConsumerWidget {
//   const SubscriptionSummaryWidget({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
//     final activeCustomers = ref.watch(activeCustomersProvider);

//     ref.listen(expiringSubscriptionsProvider, (previous, next) {
//       next.whenData((customers) {
//         activeCustomers.whenData((activeCount) {
//           SubscriptionWidgetService.updateWidgetData(
//             customers,
//             activeCount.length,
//           );
//         });
//       });
//     });

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Subscription Summary',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           const SizedBox(height: 16),
//           expiringSubscriptions.when(
//             data: (customers) {
//               if (customers.isEmpty) {
//                 return const Text(
//                   'No expiring subscriptions',
//                   style: TextStyle(color: Colors.white70),
//                 );
//               }
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Expiring Soon: ${customers.length}',
//                     style: const TextStyle(color: Colors.white70),
//                   ),
//                   const SizedBox(height: 8),
//                   ...customers.map((customer) {
//                     final daysLeft =
//                         customer.subscriptionEnd
//                             .difference(DateTime.now())
//                             .inDays;
//                     return ListTile(
//                       title: Text(
//                         customer.name,
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                       subtitle: Text(
//                         'Expires in $daysLeft days',
//                         style: const TextStyle(color: Colors.white70),
//                       ),
//                     );
//                   }),
//                 ],
//               );
//             },
//             loading: () => const CircularProgressIndicator(),
//             error: (_, __) => const Icon(Icons.error),
//           ),
//           const SizedBox(height: 16),
//           activeCustomers.when(
//             data: (customers) {
//               return Text(
//                 'Active Customers: ${customers.length}',
//                 style: const TextStyle(color: Colors.white70),
//               );
//             },
//             loading: () => const CircularProgressIndicator(),
//             error: (_, __) => const Icon(Icons.error),
//           ),
//         ],
//       ),
//     );
//   }
// }
