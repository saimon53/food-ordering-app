import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'notification_screen.dart';

const _orange = Color(0xFFFF6B35);
const _pale = Color(0xFFFFF7F2);

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Customers'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Sales'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Orders'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Manage Foods'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _CustomersTab(),
            _SalesTab(),
            _OrdersTab(),
            _FoodsTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('orders').snapshots(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('foods').snapshots(),
          builder: (context, foodSnapshot) {
            if (orderSnapshot.hasError || foodSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Could not load dashboard data. Check Firestore Rules.',
                ),
              );
            }
            if (orderSnapshot.connectionState == ConnectionState.waiting ||
                foodSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = orderSnapshot.data?.docs ?? [];
            final foods = foodSnapshot.data?.docs ?? [];
            double sales = 0;
            var pending = 0;
            var delivered = 0;
            for (final doc in orders) {
              final data = doc.data();
              final status = (data['status'] ?? 'Pending').toString();
              if (status == 'Pending') pending++;
              if (status == 'Delivered') {
                delivered++;
                sales += (data['total'] as num?)?.toDouble() ?? 0;
              }
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Business Overview',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Live summary from your Foodie database',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _StatCard(
                      title: 'Total Orders',
                      value: '${orders.length}',
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Pending Orders',
                      value: '$pending',
                      icon: Icons.hourglass_top,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      title: 'Delivered',
                      value: '$delivered',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Total Foods',
                      value: '${foods.length}',
                      icon: Icons.fastfood,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFE8DE),
                      child: Icon(Icons.payments_outlined, color: _orange),
                    ),
                    title: const Text(
                      'Delivered Order Revenue',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Sum of orders with Delivered status'),
                    trailing: Text(
                      '৳${sales.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _orange,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No orders yet.'),
                    ),
                  )
                else
                  ...orders.take(5).map((doc) {
                    final data = doc.data();
                    final total = (data['total'] as num?)?.toDouble() ?? 0;
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFE8DE),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: _orange,
                          ),
                        ),
                        title: Text(
                          (data['customerName'] ?? 'Customer').toString(),
                        ),
                        subtitle: Text(
                          'Status: ${data['status'] ?? 'Pending'}',
                        ),
                        trailing: Text(
                          '৳${total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 27),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  static const statuses = [
    'All',
    'Pending',
    'Confirmed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];
  String selectedStatus = 'All';
  String search = '';

  Future<void> updateStatus(
    BuildContext context,
    String orderId,
    String status,
  ) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      final orderSnapshot = await orderRef.get();
      final orderData = orderSnapshot.data();
      await orderRef.update({'status': status});
      final customerId = orderData?['userId']?.toString();
      if (customerId != null && customerId.isNotEmpty) {
        await NotificationService.createForUser(
          userId: customerId,
          title: 'Order status updated',
          message: 'Your order status is now: $status.',
          type: 'order_status',
          orderId: orderId,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $status')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search customer, phone or order ID',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: statuses
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: selectedStatus == s,
                      onSelected: (_) => setState(() => selectedStatus = s),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(
                  child: Text('Unable to load orders. Check Firestore Rules.'),
                );
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              final orders = docs.where((doc) {
                final d = doc.data();
                final status = (d['status'] ?? 'Pending').toString();
                final matchesStatus =
                    selectedStatus == 'All' || selectedStatus == status;
                final searchable =
                    '${doc.id} ${d['customerName'] ?? ''} ${d['phone'] ?? ''}'
                        .toLowerCase();
                return matchesStatus && searchable.contains(search);
              }).toList();
              if (orders.isEmpty)
                return const Center(child: Text('No matching orders found.'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final order = doc.data();
                  final status = (order['status'] ?? 'Pending').toString();
                  final total = (order['total'] as num?)?.toDouble() ?? 0;
                  final items = (order['items'] as List<dynamic>?) ?? [];
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFFE5DA)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${doc.id.substring(0, doc.id.length < 7 ? doc.id.length : 7)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _StatusPill(status: status),
                            ],
                          ),
                          const Divider(height: 20),
                          _detail('Customer', order['customerName'] ?? ''),
                          _detail('Phone', order['phone'] ?? ''),
                          _detail('Address', order['address'] ?? ''),
                          _detail('Payment', order['paymentMethod'] ?? ''),
                          const SizedBox(height: 8),
                          const Text(
                            'Ordered Items',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...items.map((raw) {
                            final item = Map<String, dynamic>.from(raw as Map);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• ${item['name'] ?? 'Food'} × ${item['quantity'] ?? 0}',
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Order Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '৳${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: _orange,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: statuses.contains(status) && status != 'All'
                                ? status
                                : 'Pending',
                            decoration: const InputDecoration(
                              labelText: 'Update order status',
                              border: OutlineInputBorder(),
                            ),
                            items: statuses
                                .where((s) => s != 'All')
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null && v != status)
                                updateStatus(context, doc.id, v);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _detail(String label, dynamic value) => Padding(
  padding: const EdgeInsets.only(bottom: 3),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 76,
        child: Text('$label: ', style: TextStyle(color: Colors.grey.shade700)),
      ),
      Expanded(child: Text(value.toString())),
    ],
  ),
);

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == 'Delivered'
        ? Colors.green
        : status == 'Cancelled'
        ? Colors.red
        : status == 'Pending'
        ? Colors.orange
        : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FoodsTab extends StatefulWidget {
  const _FoodsTab();
  @override
  State<_FoodsTab> createState() => _FoodsTabState();
}

class _FoodsTabState extends State<_FoodsTab> {
  final foods = FirebaseFirestore.instance.collection('foods');
  String search = '';
  String category = 'All';

  Future<void> deleteFood(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Food?'),
        content: const Text('This food will be removed from the live menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    final name = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final cat = TextEditingController(
      text: existing?['category']?.toString() ?? '',
    );
    final price = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final image = TextEditingController(
      text: existing?['image']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(foodId == null ? 'Add New Food' : 'Edit Food'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Food Name',
                          prefixIcon: Icon(Icons.fastfood),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter food name'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: cat,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter category'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price (৳)',
                          prefixIcon: Icon(Icons.payments),
                        ),
                        validator: (v) {
                          final p = double.tryParse(v ?? '');
                          return p == null || p <= 0
                              ? 'Enter a valid price'
                              : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: image,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (https://...)',
                          prefixIcon: Icon(Icons.image),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          return (s.startsWith('https://') ||
                                  s.startsWith('http://'))
                              ? null
                              : 'Enter a valid image URL';
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: description,
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
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        final data = <String, dynamic>{
                          'name': name.text.trim(),
                          'category': cat.text.trim(),
                          'price': double.parse(price.text.trim()),
                          'image': image.text.trim(),
                          'description': description.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        try {
                          if (foodId == null) {
                            data['createdAt'] = FieldValue.serverTimestamp();
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
                          if (dialogContext.mounted)
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
          ),
        ),
      );
    } finally {
      name.dispose();
      cat.dispose();
      price.dispose();
      image.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: _orange,
      foregroundColor: Colors.white,
      onPressed: () => showFoodForm(context),
      icon: const Icon(Icons.add),
      label: const Text('Add Food'),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: foods.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Unable to load foods. Check Firestore Rules and the foods collection.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        final categories = <String>{
          'All',
          ...docs.map((d) => (d.data()['category'] ?? 'Other').toString()),
        }.toList();
        final filtered =
            docs.where((doc) {
              final d = doc.data();
              final matchesSearch = '${d['name'] ?? ''} ${d['category'] ?? ''}'
                  .toLowerCase()
                  .contains(search);
              final matchesCategory =
                  category == 'All' ||
                  (d['category'] ?? '').toString() == category;
              return matchesSearch && matchesCategory;
            }).toList()..sort(
              (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                (b.data()['name'] ?? '').toString(),
              ),
            );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search food name or category',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onChanged: (v) =>
                    setState(() => search = v.toLowerCase().trim()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: categories
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setState(() => category = c),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching food found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final imageUrl = data['image']?.toString() ?? '';
                        final priceValue =
                            (data['price'] as num?)?.toDouble() ??
                            double.tryParse(data['price']?.toString() ?? '') ??
                            0;
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: const BorderSide(color: Color(0xFFFFE5DA)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: imageUrl.startsWith('http')
                                      ? Image.network(
                                          imageUrl,
                                          width: 78,
                                          height: 78,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _foodPlaceholder(),
                                        )
                                      : _foodPlaceholder(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['name'] ?? 'Unnamed Food')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        (data['category'] ?? '').toString(),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '৳${priceValue.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: _orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit food',
                                  onPressed: () => showFoodForm(
                                    context,
                                    foodId: doc.id,
                                    existing: data,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete food',
                                  onPressed: () => deleteFood(context, doc.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );

  Widget _foodPlaceholder() => Container(
    width: 78,
    height: 78,
    color: Colors.orange.shade50,
    child: const Icon(Icons.fastfood, color: _orange, size: 32),
  );
}

class _CustomersTab extends StatelessWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text(
              'Could not load customer details. Check Firestore Rules.',
            ),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        final Map<String, Map<String, dynamic>> customers = {};
        for (final doc in docs) {
          final d = doc.data();
          final uid = (d['userId'] ?? '').toString();
          if (uid.isEmpty) continue;
          final current = customers.putIfAbsent(
            uid,
            () => {
              'userId': uid,
              'name': d['customerName'] ?? 'Customer',
              'phone': d['phone'] ?? 'Not provided',
              'address': d['address'] ?? 'Not provided',
              'email': d['email'] ?? 'Not available',
              'orders': 0,
              'spent': 0.0,
            },
          );
          current['orders'] = (current['orders'] as int) + 1;
          current['spent'] =
              (current['spent'] as double) +
              ((d['total'] as num?)?.toDouble() ??
                  double.tryParse('${d['total']}') ??
                  0);
          if ((d['customerName'] ?? '').toString().isNotEmpty)
            current['name'] = d['customerName'];
          if ((d['phone'] ?? '').toString().isNotEmpty)
            current['phone'] = d['phone'];
          if ((d['address'] ?? '').toString().isNotEmpty)
            current['address'] = d['address'];
          if ((d['email'] ?? '').toString().isNotEmpty)
            current['email'] = d['email'];
        }
        final list = customers.values.toList()
          ..sort((a, b) => (b['orders'] as int).compareTo(a['orders'] as int));
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Customers (${list.length})',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text('Customer details are collected from existing orders.'),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No customers with orders found.'),
                ),
              ),
            ...list.map(
              (c) => Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE8DE),
                    child: Icon(Icons.person, color: _orange),
                  ),
                  title: Text(
                    c['name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${c['phone']}  •  ${c['orders']} orders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(c['name'].toString()),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detail('User ID', c['userId']),
                          _detail('Email', c['email']),
                          _detail('Phone', c['phone']),
                          _detail('Address', c['address']),
                          _detail('Orders', c['orders']),
                          _detail(
                            'Order total',
                            '৳${(c['spent'] as double).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SalesTab extends StatelessWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text('Could not load sales data. Check Firestore Rules.'),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        final delivered = docs
            .where((d) => (d.data()['status'] ?? '') == 'Delivered')
            .toList();
        double revenue = 0;
        final daily = List<double>.filled(7, 0);
        final now = DateTime.now();
        for (final doc in delivered) {
          final d = doc.data();
          final total =
              (d['total'] as num?)?.toDouble() ??
              double.tryParse('${d['total']}') ??
              0;
          revenue += total;
          final rawDate = d['createdAt'];
          DateTime? date;
          if (rawDate is Timestamp) date = rawDate.toDate();
          if (date != null) {
            final daysAgo = DateTime(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime(date.year, date.month, date.day)).inDays;
            if (daysAgo >= 0 && daysAgo < 7) daily[6 - daysAgo] += total;
          }
        }
        final maxValue = daily.fold<double>(0, (a, b) => a > b ? a : b);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sales Analytics',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _StatCard(
                  title: 'Total Revenue',
                  value: '৳${revenue.toStringAsFixed(0)}',
                  icon: Icons.payments,
                  color: Colors.green,
                ),
                _StatCard(
                  title: 'Delivered Orders',
                  value: '${delivered.length}',
                  icon: Icons.task_alt,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: 'All Orders',
                  value: '${docs.length}',
                  icon: Icons.shopping_bag,
                  color: Colors.deepPurple,
                ),
                _StatCard(
                  title: 'Average Sale',
                  value:
                      '৳${delivered.isEmpty ? '0' : (revenue / delivered.length).toStringAsFixed(0)}',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Delivered Sales — Last 7 Days',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 210,
                  child: CustomPaint(
                    painter: _SalesChartPainter(
                      values: daily,
                      maxValue: maxValue,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Revenue includes only orders with Delivered status and uses the order creation date.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  _SalesChartPainter({required this.values, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0, bottom = 25.0, top = 12.0, right = 8.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = _orange
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = _orange.withOpacity(.12)
      ..style = PaintingStyle.fill;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(
          text: maxValue == 0
              ? '0'
              : (maxValue * (4 - i) / 4).toStringAsFixed(0),
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 5);
      label.paint(canvas, Offset(0, y - 6));
    }
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / (values.length - 1);
      final y =
          chart.bottom -
          (maxValue == 0 ? 0 : values[i] / maxValue * chart.height);
      points.add(Offset(x, y));
      final label = TextPainter(
        text: TextSpan(
          text: [
            '${DateTime.now().subtract(const Duration(days: 6)).day}',
            '2',
            '3',
            '4',
            '5',
            '6',
            'Today',
          ][i],
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, chart.bottom + 5));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);
    final dot = Paint()..color = _orange;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter old) =>
      old.values != values || old.maxValue != maxValue;
}
