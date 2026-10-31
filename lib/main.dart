import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_screens.dart';
import 'order_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FoodOrderingApp());
}

// ================= APP =================

class FoodOrderingApp extends StatelessWidget {
  const FoodOrderingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Foodie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBF7),
      ),
      home: const AuthGate(),
    );
  }
}

// ================= AUTH GATE =================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const MainScreen();
        return const LoginScreen();
      },
    );
  }
}

// ================= FOOD MODEL =================
class Food {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String image;

  const Food({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.image,
  });

  factory Food.fromFirestore(String id, Map<String, dynamic> data) {
    return Food(
      id: id,
      name: data['name']?.toString() ?? 'Unnamed Food',
      description: data['description']?.toString() ?? '',
      price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
      category: data['category']?.toString() ?? 'Other',
      image: data['image']?.toString() ?? '',
    );
  }
}

class CartItem {
  final Food food;
  int quantity;

  CartItem({required this.food, this.quantity = 1});
}

// ================= FOOD DATA =================

// ================= FOOD IMAGE =================

class FoodImage extends StatelessWidget {
  final String image;
  final double? height;
  final double? width;

  const FoodImage({super.key, required this.image, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width,
      color: Colors.orange.shade50,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, size: 50, color: Colors.deepOrange),
    );

    if (image.isEmpty) {
      return fallback;
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(
        image,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return fallback;
        },
      );
    }

    return Image.asset(
      image,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return fallback;
      },
    );
  }
}

// ================= HOME SCREEN =================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final Map<String, CartItem> cart = {};
  String selectedCategory = 'All';
  String searchQuery = '';

  final List<String> categories = ['All', 'Burger', 'Pizza', 'Snacks', 'Rice'];

  int get totalCartItems =>
      cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => cart.values.fold(
    0.0,
    (sum, item) => sum + item.food.price * item.quantity,
  );

  List<Food> filterFoods(List<Food> foods) {
    return foods.where((food) {
      final matchesCategory =
          selectedCategory == 'All' ||
          food.category.toLowerCase() == selectedCategory.toLowerCase();

      final matchesSearch = food.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );

      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> toggleFavorite(Food food, bool isFavorite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await ref.set({
        'favorites': isFavorite
            ? FieldValue.arrayRemove([food.id])
            : FieldValue.arrayUnion([food.id]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? '${food.name} removed from favorites'
                : '${food.name} added to favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorites.')),
      );
    }
  }

  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void addToCart(Food food) {
    setState(() {
      if (cart.containsKey(food.id)) {
        cart[food.id]!.quantity++;
      } else {
        cart[food.id] = CartItem(food: food);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void changeQuantity(String foodId, int change) {
    setState(() {
      if (!cart.containsKey(foodId)) return;
      cart[foodId]!.quantity += change;
      if (cart[foodId]!.quantity <= 0) cart.remove(foodId);
    });
  }

  void removeFromCart(String foodId) {
    setState(() => cart.remove(foodId));
  }

  void openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cart: cart,
          onIncrease: (id) => changeQuantity(id, 1),
          onDecrease: (id) => changeQuantity(id, -1),
          onRemove: removeFromCart,
          onCheckout: openCheckout,
        ),
      ),
    );
  }

  void openCheckout() {
    if (cart.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cart: cart.values
              .map((item) => CartItem(food: item.food, quantity: item.quantity))
              .toList(),
          onOrderPlaced: () {
            setState(() => cart.clear());
          },
        ),
      ),
    );
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  void openOrderHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Foodie',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Favorite Foods',
            icon: const Icon(Icons.favorite_border, color: Colors.red),
            onPressed: openFavorites,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'My Cart',
            onPressed: openCart,
            icon: Badge(
              isLabelVisible: totalCartItems > 0,
              label: Text('$totalCartItems'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            tooltip: 'My Orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: openOrderHistory,
          ),
          if (user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admins')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final isAdmin = snapshot.data?.data()?['active'] == true;
                if (!isAdmin) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Admin Panel',
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminPanelScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'logout') logout();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'account',
                enabled: false,
                child: Text(user?.email ?? 'Logged in user'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search your favourite food...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    selectedColor: Colors.deepOrange.shade100,
                    onSelected: (_) =>
                        setState(() => selectedCategory = category),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Popular Foods',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text('Live Menu'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('foods')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load foods.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final foods =
                    snapshot.data?.docs
                        .map((doc) => Food.fromFirestore(doc.id, doc.data()))
                        .toList() ??
                    <Food>[];

                final visibleFoods = foods.where((food) {
                  final matchesCategory =
                      selectedCategory == 'All' ||
                      food.category.toLowerCase() ==
                          selectedCategory.toLowerCase();

                  final matchesSearch = food.name.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );

                  return matchesCategory && matchesSearch;
                }).toList();

                if (visibleFoods.isEmpty) {
                  return const Center(
                    child: Text(
                      'No food found. Add food from Admin Panel.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  itemCount: visibleFoods.length,
                  itemBuilder: (context, index) {
                    final food = visibleFoods[index];
                    final currentUser = FirebaseAuth.instance.currentUser;

                    void openDetails() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodDetailsScreen(
                            food: food,
                            onAddToCart: () => addToCart(food),
                          ),
                        ),
                      );
                    }

                    if (currentUser == null) {
                      return FoodCard(
                        food: food,
                        isFavorite: false,
                        onToggleFavorite: () {},
                        onTap: openDetails,
                        onAdd: () => addToCart(food),
                      );
                    }

                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .snapshots(),
                      builder: (context, favoriteSnapshot) {
                        final data = favoriteSnapshot.data?.data() ?? {};

                        final favoriteIds = List<String>.from(
                          data['favorites'] ?? [],
                        );

                        final isFavorite = favoriteIds.contains(food.id);

                        return FoodCard(
                          food: food,
                          isFavorite: isFavorite,
                          onToggleFavorite: () =>
                              toggleFavorite(food, isFavorite),
                          onTap: openDetails,
                          onAdd: () => addToCart(food),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= FOOD CARD =================

class FoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const FoodCard({
    super.key,
    required this.food,
    required this.onTap,
    required this.onAdd,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: onTap,
                child: FoodImage(image: food.image),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
              food.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '৳${food.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onTap,
                    child: const Text('Details'),
                  ),
                ),
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                ),
                IconButton(
                  tooltip: 'Add to cart',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= FOOD DETAILS SCREEN =================

class FoodDetailsScreen extends StatelessWidget {
  final Food food;
  final VoidCallback onAddToCart;

  const FoodDetailsScreen({
    super.key,
    required this.food,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FoodImage(
              image: food.image,
              height: 250,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            food.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '৳${food.price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.deepOrange,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Chip(label: Text(food.category)),
          const SizedBox(height: 12),
          Text(food.description, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              onAddToCart();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }
}

// ================= CART SCREEN =================

class CartScreen extends StatelessWidget {
  final Map<String, CartItem> cart;
  final void Function(String) onIncrease;
  final void Function(String) onDecrease;
  final void Function(String) onRemove;
  final VoidCallback onCheckout;

  const CartScreen({
    super.key,
    required this.cart,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final items = cart.values.toList();
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.food.price * item.quantity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('Your cart is empty', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: FoodImage(
                                  image: item.food.image,
                                  height: 85,
                                  width: 85,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.food.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '৳${item.food.price.toStringAsFixed(0)} each',
                                    ),
                                    Text(
                                      'Subtotal: ৳${(item.food.price * item.quantity).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              onDecrease(item.food.id),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text('${item.quantity}'),
                                        IconButton(
                                          onPressed: () =>
                                              onIncrease(item.food.id),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove item',
                                          onPressed: () =>
                                              onRemove(item.food.id),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      summaryRow('Subtotal', subtotal),
                      summaryRow('Delivery Fee', 50),
                      const Divider(),
                      summaryRow('Total', subtotal + 50, bold: true),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onCheckout,
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ================= CHECKOUT SCREEN =================

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  String paymentMethod = 'Cash on Delivery';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadCustomerProfile();
  }

  Future<void> loadCustomerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted || !doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      nameController.text = data['name']?.toString() ?? '';
      phoneController.text = data['phone']?.toString() ?? '';
      addressController.text = data['address']?.toString() ?? '';
    } catch (e) {
      debugPrint('Could not load customer profile: $e');
    }
  }

  double get subtotal => widget.cart.fold<double>(
    0,
    (sum, item) => sum + item.food.price * item.quantity,
  );

  double get deliveryFee => 50;
  double get total => subtotal + deliveryFee;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
    if (isSubmitting) return;

    if (!formKey.currentState!.validate()) return;

    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before placing an order.')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final items = widget.cart.map((item) {
        return <String, dynamic>{
          'foodId': item.food.id,
          'name': item.food.name,
          'category': item.food.category,
          'price': item.food.price,
          'quantity': item.quantity,
          'image': item.food.image,
          'itemTotal': item.food.price * item.quantity,
        };
      }).toList();

      final orderData = <String, dynamic>{
        'userId': user.uid,
        'customerName': nameController.text.trim(),
        'email': user.email ?? '',
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'paymentMethod': paymentMethod,
        'items': items,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final document = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);

      if (!mounted) return;

      final savedName = nameController.text.trim();
      final savedPhone = phoneController.text.trim();
      final savedAddress = addressController.text.trim();
      final savedPaymentMethod = paymentMethod;
      final savedTotal = total;

      widget.onOrderPlaced();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: document.id,
            customerName: savedName,
            phone: savedPhone,
            address: savedAddress,
            paymentMethod: savedPaymentMethod,
            total: savedTotal,
          ),
        ),
        (route) => route.isFirst,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save order: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Order failed: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return 'Please enter your phone number';
                if (phone.length < 8) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your delivery address';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              value: 'Cash on Delivery',
              groupValue: paymentMethod,
              title: const Text('Cash on Delivery'),
              secondary: const Icon(Icons.payments_outlined),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              value: 'Mobile Banking (Demo)',
              groupValue: paymentMethod,
              title: const Text('Mobile Banking (Demo)'),
              secondary: const Icon(Icons.phone_android),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              value: 'Card Payment (Demo)',
              groupValue: paymentMethod,
              title: const Text('Card Payment (Demo)'),
              secondary: const Icon(Icons.credit_card),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            const SizedBox(height: 12),
            const Divider(),
            summaryRow('Subtotal', subtotal),
            summaryRow('Delivery Fee', deliveryFee),
            const Divider(),
            summaryRow('Total', total, bold: true),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : placeOrder,
                icon: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(isSubmitting ? 'Placing Order...' : 'Place Order'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Mobile banking and card options are demo options. '
              'They do not process real payments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ORDER CONFIRMATION =================

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String phone;
  final String address;
  final String paymentMethod;
  final double total;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.check_circle, color: Colors.green, size: 90),
          const SizedBox(height: 16),
          const Text(
            'Order Placed Successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thank you for ordering with Foodie.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Order ID',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          SelectableText(
            orderId,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  summaryTextRow('Customer', customerName),
                  summaryTextRow('Phone', phone),
                  summaryTextRow('Address', address),
                  summaryTextRow('Payment', paymentMethod),
                  const Divider(),
                  summaryTextRow(
                    'Total Amount',
                    '৳${total.toStringAsFixed(0)}',
                    bold: true,
                  ),
                  summaryTextRow('Order Status', 'Pending'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SUMMARY HELPERS =================

Widget summaryRow(String label, double amount, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '৳${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 18 : 14,
            color: bold ? Colors.deepOrange : null,
          ),
        ),
      ],
    ),
  );
}

Widget summaryTextRow(String label, String value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? Colors.deepOrange : null,
            ),
          ),
        ),
      ],
    ),
  );
}
