import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> toggleFavorite(String foodId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await ref.set({
      'favorites': FieldValue.arrayRemove([foodId]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorite Foods')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load favorites.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? {};
          final ids = List<String>.from(data['favorites'] ?? []);

          if (ids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 60),
                  SizedBox(height: 12),
                  Text('No favorite foods yet.'),
                  Text('Tap the heart on a food to save it.'),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('foods').snapshots(),
            builder: (context, foodSnapshot) {
              if (foodSnapshot.hasError) {
                return const Center(
                  child: Text('Could not load food details.'),
                );
              }

              if (foodSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final favoriteFoods = foodSnapshot.data!.docs
                  .where((doc) => ids.contains(doc.id))
                  .map((doc) => Food.fromFirestore(doc.id, doc.data()))
                  .toList();

              if (favoriteFoods.isEmpty) {
                return const Center(
                  child: Text(
                    'No favorite foods found. They may have been deleted.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: favoriteFoods.length,
                itemBuilder: (context, index) {
                  final food = favoriteFoods[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 65,
                          height: 65,
                          child: FoodImage(image: food.image),
                        ),
                      ),
                      title: Text(food.name),
                      subtitle: Text('৳${food.price.toStringAsFixed(0)}'),
                      trailing: IconButton(
                        tooltip: 'Remove from favorites',
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () async {
                          try {
                            await toggleFavorite(food.id);
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not update favorites.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
