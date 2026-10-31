import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String paymentMethod,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in before placing an order.');
    }

    if (items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final orderData = <String, dynamic>{
      'userId': user.uid,
      'customerName': customerName,
      'email': user.email ?? '',
      'phone': phone,
      'address': address,
      'paymentMethod': paymentMethod,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final document = await _firestore.collection('orders').add(orderData);

    return document.id;
  }
}
