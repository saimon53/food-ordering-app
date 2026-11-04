import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static Future<void> createForUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? orderId,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'message': message,
          'type': type,
          'orderId': orderId ?? '',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view notifications.')),
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final unread = await ref.where('isRead', isEqualTo: false).get();
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in unread.docs) {
                batch.update(doc.reference, {'isRead': true});
              }
              await batch.commit();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Could not load notifications.'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('You have no notifications yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;
              final timestamp = data['createdAt'];
              final date = timestamp is Timestamp ? timestamp.toDate() : null;
              return Card(
                color: isRead
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer
                          .withOpacity(.35),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      data['type'] == 'order_status'
                          ? Icons.local_shipping_outlined
                          : Icons.notifications_outlined,
                    ),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Notification',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message']?.toString() ?? ''),
                      if (date != null)
                        Text(
                          '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: isRead
                      ? null
                      : const Icon(
                          Icons.circle,
                          size: 10,
                          color: Colors.deepOrange,
                        ),
                  onTap: () async {
                    if (!isRead) await doc.reference.update({'isRead': true});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
