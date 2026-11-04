import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  static const List<String> statuses = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
  ];

  int getStatusIndex(String status) => statuses.indexOf(status);

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view your orders.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load orders. Please try again.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data?.docs.toList() ?? [];
          orders.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            final aMillis = aTime is Timestamp
                ? aTime.millisecondsSinceEpoch
                : 0;
            final bMillis = bTime is Timestamp
                ? bTime.millisecondsSinceEpoch
                : 0;
            return bMillis.compareTo(aMillis);
          });

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 60),
                  SizedBox(height: 12),
                  Text('You have no orders yet.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final order = doc.data();
              final status = order['status']?.toString() ?? 'Pending';
              final total = _number(order['total']);
              final rawItems = order['items'];
              final items = rawItems is List ? rawItems : <dynamic>[];
              final isCancelled = status == 'Cancelled';
              final currentIndex = getStatusIndex(status);
              final createdAt = order['createdAt'];
              final shortId = doc.id.length > 6
                  ? doc.id.substring(0, 6)
                  : doc.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Order #$shortId',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '৳${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                      if (createdAt is Timestamp) ...[
                        const SizedBox(height: 8),
                        Text('Date: ${createdAt.toDate().toLocal()}'),
                      ],
                      const Divider(height: 24),
                      const Text(
                        'Order Items',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...items.map((rawItem) {
                        final item = rawItem is Map
                            ? Map<String, dynamic>.from(rawItem)
                            : <String, dynamic>{};
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${item['name'] ?? 'Food'} × ${item['quantity'] ?? 0}',
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Tracking',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isCancelled)
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 30,
                          ),
                          title: Text(
                            'Order Cancelled',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('This order has been cancelled.'),
                        )
                      else if (currentIndex == -1)
                        Text('Current status: $status')
                      else
                        ...List.generate(statuses.length, (step) {
                          final completed = step <= currentIndex;
                          final isCurrent = step == currentIndex;
                          const icons = [
                            Icons.receipt_long,
                            Icons.check_circle_outline,
                            Icons.restaurant,
                            Icons.delivery_dining,
                            Icons.task_alt,
                          ];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Icon(
                                    icons[step],
                                    color: completed
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 25,
                                  ),
                                  if (step < statuses.length - 1)
                                    Container(
                                      width: 2,
                                      height: 28,
                                      color: completed
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    statuses[step],
                                    style: TextStyle(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: completed
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                const Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          );
                        }),
                      const SizedBox(height: 12),
                      Text('Payment: ${order['paymentMethod'] ?? 'N/A'}'),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('View Live Tracking'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingScreen(orderId: doc.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
