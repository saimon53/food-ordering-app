import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Manage Foods'),
            ],
          ),
        ),
        body: const TabBarView(children: [_OrdersTab(), _FoodsTab()]),
      ),
    );
  }
}

// ---------------- ORDERS TAB ----------------

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  static const statuses = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  Future<void> updateStatus(
    BuildContext context,
    String orderId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': status},
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Status updated: $status')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load orders. Check Rules.'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return const Center(child: Text('No orders found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final order = doc.data();

            final status = order['status']?.toString() ?? 'Pending';
            final total = (order['total'] as num?)?.toDouble() ?? 0;
            final selectedStatus = statuses.contains(status)
                ? status
                : 'Pending';
            final items = (order['items'] as List<dynamic>?) ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${doc.id.substring(0, doc.id.length < 6 ? doc.id.length : 6)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Customer: ${order['customerName'] ?? ''}'),
                    Text('Phone: ${order['phone'] ?? ''}'),
                    Text('Address: ${order['address'] ?? ''}'),
                    Text('Payment: ${order['paymentMethod'] ?? ''}'),
                    Text('Total: ৳${total.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...items.map((rawItem) {
                      final item = Map<String, dynamic>.from(rawItem as Map);
                      return Text(
                        '${item['name'] ?? 'Food'} × ${item['quantity'] ?? 0}',
                      );
                    }),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedStatus,
                            items: statuses.map((value) {
                              return DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null || value == status) return;
                              updateStatus(context, doc.id, value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- FOODS TAB ----------------

class _FoodsTab extends StatelessWidget {
  const _FoodsTab();

  CollectionReference<Map<String, dynamic>> get foods =>
      FirebaseFirestore.instance.collection('foods');

  Future<void> deleteFood(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Food?'),
        content: const Text('Are you sure you want to delete this food?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await foods.doc(id).delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food deleted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> showFoodForm(
    BuildContext context, {
    String? foodId,
    Map<String, dynamic>? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?['category']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing?['image']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );

    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(foodId == null ? 'Add New Food' : 'Edit Food'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Food Name',
                              prefixIcon: Icon(Icons.fastfood),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter food name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Category (Burger, Pizza...)',
                              prefixIcon: Icon(Icons.category),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter category'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price (৳)',
                              prefixIcon: Icon(Icons.payments),
                            ),
                            validator: (value) {
                              final price = double.tryParse(value ?? '');
                              if (price == null || price <= 0) {
                                return 'Enter a valid price';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: imageController,
                            decoration: const InputDecoration(
                              labelText: 'Image URL',
                              prefixIcon: Icon(Icons.image),
                            ),
                            validator: (value) {
                              final url = value?.trim() ?? '';
                              if (url.isEmpty ||
                                  !(url.startsWith('https://') ||
                                      url.startsWith('http://'))) {
                                return 'Enter a valid image URL';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.description),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => saving = true);

                            final data = <String, dynamic>{
                              'name': nameController.text.trim(),
                              'category': categoryController.text.trim(),
                              'price': double.parse(
                                priceController.text.trim(),
                              ),
                              'image': imageController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            try {
                              if (foodId == null) {
                                data['createdAt'] =
                                    FieldValue.serverTimestamp();
                                await foods.add(data);
                              } else {
                                await foods.doc(foodId).update(data);
                              }

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    foodId == null
                                        ? 'Food added successfully'
                                        : 'Food updated successfully',
                                  ),
                                ),
                              );
                            } catch (e) {
                              setDialogState(() => saving = false);

                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Food'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      categoryController.dispose();
      priceController.dispose();
      imageController.dispose();
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        onPressed: () => showFoodForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: foods.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load foods. Check Firestore Rules and the foods collection.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final foodDocs = snapshot.data?.docs ?? [];

          if (foodDocs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No foods added yet.\nTap "Add Food" to create your first food item.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: foodDocs.length,
            itemBuilder: (context, index) {
              final doc = foodDocs[index];
              final food = doc.data();
              final name = food['name']?.toString() ?? 'Unnamed Food';
              final category = food['category']?.toString() ?? '';
              final price = (food['price'] as num?)?.toDouble() ?? 0;
              final image = food['image']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: image.startsWith('http')
                            ? Image.network(
                                image,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 76,
                                  height: 76,
                                  color: Colors.orange.shade50,
                                  child: const Icon(Icons.fastfood, size: 32),
                                ),
                              )
                            : Container(
                                width: 76,
                                height: 76,
                                color: Colors.orange.shade50,
                                child: const Icon(Icons.fastfood, size: 32),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(category),
                            Text(
                              '৳${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit Food',
                        onPressed: () => showFoodForm(
                          context,
                          foodId: doc.id,
                          existing: food,
                        ),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: 'Delete Food',
                        onPressed: () => deleteFood(context, doc.id),
                        icon: const Icon(Icons.delete, color: Colors.red),
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
