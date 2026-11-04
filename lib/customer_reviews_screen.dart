import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Add this widget to a food details page with the Firestore food document ID.
class CustomerReviewsSection extends StatelessWidget {
  final String foodId;

  const CustomerReviewsSection({super.key, required this.foodId});

  CollectionReference<Map<String, dynamic>> get _reviews =>
      FirebaseFirestore.instance
          .collection('foods')
          .doc(foodId)
          .collection('reviews');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviews.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load reviews. Please try again.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;
        QueryDocumentSnapshot<Map<String, dynamic>>? ownReview;
        if (currentUser != null) {
          for (final doc in docs) {
            if (doc.id == currentUser.uid) {
              ownReview = doc;
              break;
            }
          }
        }

        final totalRating = docs.fold<double>(0, (sum, doc) {
          final value = doc.data()['rating'];
          return sum + (value is num ? value.toDouble() : 0);
        });
        final average = docs.isEmpty ? 0.0 : totalRating / docs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            const Text(
              'Customer Ratings & Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 30),
                const SizedBox(width: 6),
                Text(average.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(${docs.length} reviews)',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(ownReview == null ? 'Write a Review' : 'Edit My Review'),
                onPressed: currentUser == null
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          builder: (_) => _ReviewDialog(
                            foodId: foodId,
                            existingReview: ownReview?.data(),
                          ),
                        ),
              ),
            ),
            if (currentUser == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Log in to submit a review.',
                    style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No reviews yet. Be the first to review!'),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final rating = data['rating'] is num
                    ? (data['rating'] as num).toInt().clamp(1, 5)
                    : 0;
                final name = (data['userName'] ?? 'Customer').toString();
                final comment = (data['comment'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const CircleAvatar(child: Icon(Icons.person)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          Text('$rating/5',
                              style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 19,
                            ),
                          ),
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(comment),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final String foodId;
  final Map<String, dynamic>? existingReview;

  const _ReviewDialog({required this.foodId, this.existingReview});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final old = widget.existingReview;
    if (old != null) {
      final oldRating = old['rating'];
      _rating = oldRating is num ? oldRating.toInt().clamp(1, 5) : 5;
      _commentController.text = (old['comment'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('foods')
          .doc(widget.foodId)
          .collection('reviews')
          .doc(user.uid);
      final displayName = user.displayName?.trim();
      final userName = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (user.email?.split('@').first ?? 'Customer');
      final data = <String, dynamic>{
        'userId': user.uid,
        'userName': userName,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.existingReview == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await ref.set(data, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your review has been saved.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save review: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingReview == null ? 'Write a Review' : 'Edit Review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tap a star to rate this food'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                );
              }),
            ),
            Text('$_rating out of 5 stars'),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Your review',
                hintText: 'Tell others about your experience',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
