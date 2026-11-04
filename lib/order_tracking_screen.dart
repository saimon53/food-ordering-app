import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  static const Color orange = Color(0xFFFF6B35);
  static const List<String> stages = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
  ];

  int _stageIndex(String status) => stages.indexOf(status);

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(title: const Text('Live Order Tracking')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load order tracking. Please check your internet connection and Firestore Rules.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found.'));
          }

          final order = snapshot.data!.data() ?? <String, dynamic>{};
          final status = (order['status'] ?? 'Pending').toString();
          final cancelled = status == 'Cancelled';
          final currentIndex = _stageIndex(status);
          final items = order['items'] is List
              ? order['items'] as List
              : <dynamic>[];
          final total = _number(order['total']);
          final createdAt = order['createdAt'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your order status',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: cancelled ? Colors.red : orange,
                            ),
                          ),
                        ),
                        Icon(
                          cancelled
                              ? Icons.cancel_outlined
                              : status == 'Delivered'
                              ? Icons.check_circle
                              : Icons.local_shipping_outlined,
                          color: cancelled ? Colors.red : orange,
                          size: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order ID: $orderId',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    if (cancelled)
                      const Text(
                        'This order has been cancelled. Please contact the restaurant if you need help.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      ...List.generate(stages.length, (index) {
                        final completed = currentIndex >= index;
                        final isCurrent = currentIndex == index;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 34,
                              child: Column(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: completed
                                          ? orange
                                          : Colors.grey.shade200,
                                    ),
                                    child: Icon(
                                      completed
                                          ? Icons.check
                                          : Icons.circle_outlined,
                                      size: 16,
                                      color: completed
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (index != stages.length - 1)
                                    Container(
                                      width: 2,
                                      height: 35,
                                      color: currentIndex > index
                                          ? orange
                                          : Colors.grey.shade300,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 3,
                                  bottom: 28,
                                ),
                                child: Text(
                                  stages[index],
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: completed
                                        ? const Color(0xFF292522)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            if (isCurrent)
                              const Text(
                                'Current',
                                style: TextStyle(
                                  color: orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        );
                      }),
                    const SizedBox(height: 4),
                    const Text(
                      'This page updates automatically when the restaurant changes your order status.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _infoCard(
                title: 'Delivery Information',
                children: [
                  _row('Customer', order['customerName']?.toString() ?? '-'),
                  _row('Phone', order['phone']?.toString() ?? '-'),
                  _row('Address', order['address']?.toString() ?? '-'),
                  _row('Payment', order['paymentMethod']?.toString() ?? '-'),
                  if (createdAt is Timestamp)
                    _row(
                      'Order placed',
                      createdAt.toDate().toLocal().toString().substring(0, 16),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _infoCard(
                title: 'Order Items',
                children: [
                  if (items.isEmpty) const Text('No item details available.'),
                  ...items.map((raw) {
                    final item = raw is Map
                        ? Map<String, dynamic>.from(raw)
                        : <String, dynamic>{};
                    final name = item['name']?.toString() ?? 'Food';
                    final quantity = item['quantity']?.toString() ?? '1';
                    final itemTotal = _number(item['itemTotal']);
                    return _row(
                      '$name × $quantity',
                      '৳${itemTotal.toStringAsFixed(0)}',
                    );
                  }),
                  const Divider(),
                  _row(
                    'Total Amount',
                    '৳${total.toStringAsFixed(0)}',
                    bold: true,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? orange : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
