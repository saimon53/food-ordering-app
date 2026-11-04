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
import 'order_tracking_screen.dart';
import 'customer_reviews_screen.dart';
import 'notification_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          primary: const Color(0xFFFF6B35),
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF292522),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF292522),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFE2D4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
          ),
        ),
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

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
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
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Text('Foodie'),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid ?? '')
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: openNotifications,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_none),
                ),
              );
            },
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A50), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good food, good mood!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Find your favourite meal today.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search your favourite food...',
                prefixIcon: const Icon(Icons.search),
                border: InputBorder.none,
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
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFE9DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: onTap,
                child: Hero(
                  tag: 'food-image-${food.id}',
                  child: FoodImage(image: food.image),
                ),
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
      backgroundColor: const Color(0xFFFFF8F2),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF292522),
            title: const Text('Food Details'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'food-image-${food.id}',
                    child: FoodImage(
                      image: food.image,
                      width: double.infinity,
                      height: 300,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        food.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF292522),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '৳${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 23,
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: Color(0xFFFF6B35),
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        food.category,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Icon(
                        Icons.local_dining,
                        color: Color(0xFFFF6B35),
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Freshly prepared',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    food.description.trim().isEmpty
                        ? 'No description is available for this food yet.'
                        : food.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE2D4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFFF6B35)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add this item to your cart and continue to checkout when you are ready.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomerReviewsSection(foodId: food.id),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () {
              onAddToCart();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
              'Add to Cart • ৳${food.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
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
    const deliveryFee = 50.0;
    final total = subtotal + (items.isEmpty ? 0 : deliveryFee);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${items.length} items',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Add your favourite food and it will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text('Explore Food'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFFE4D8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.035),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: FoodImage(
                                  image: item.food.image,
                                  height: 104,
                                  width: 104,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.food.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.food.category,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '৳${item.food.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _quantityButton(
                                          Icons.remove,
                                          () => onDecrease(item.food.id),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        _quantityButton(
                                          Icons.add,
                                          () => onIncrease(item.food.id),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Remove item',
                                          onPressed: () =>
                                              onRemove(item.food.id),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
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
                  padding: const EdgeInsets.fromLTRB(20, 17, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal'),
                            Text('৳${subtotal.toStringAsFixed(0)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee'),
                            Text('৳${deliveryFee.toStringAsFixed(0)}'),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '৳${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: onCheckout,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text(
                              'Proceed to Checkout',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.deepOrange.shade50,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: Colors.deepOrange),
        ),
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
  final couponController = TextEditingController();
  final transactionIdController = TextEditingController();

  String paymentMethod = 'Cash on Delivery';
  bool isSubmitting = false;
  bool isApplyingCoupon = false;
  String? appliedCouponCode;
  String? couponMessage;
  double discountAmount = 0;

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
  double get total =>
      (subtotal - discountAmount).clamp(0, double.infinity).toDouble() +
      deliveryFee;

  double _number(dynamic value, [double fallback = 0]) =>
      double.tryParse(value?.toString() ?? '') ?? fallback;

  Future<double> _calculateCouponDiscount(String code) async {
    final doc = await FirebaseFirestore.instance
        .collection('coupons')
        .doc(code)
        .get();
    if (!doc.exists || doc.data() == null)
      throw Exception('Coupon code not found.');
    final data = doc.data()!;
    if (data['active'] != true) throw Exception('This coupon is inactive.');

    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw Exception('This coupon has expired.');
    }

    final minimumOrder = _number(data['minOrder']);
    if (subtotal < minimumOrder) {
      throw Exception(
        'Minimum order ৳${minimumOrder.toStringAsFixed(0)} required.',
      );
    }

    final value = _number(data['discountValue']);
    final type = (data['discountType'] ?? 'percent').toString().toLowerCase();
    if (value <= 0) throw Exception('Invalid coupon configuration.');

    double discount;
    if (type == 'fixed') {
      discount = value;
    } else if (type == 'percent') {
      discount = subtotal * value / 100;
      final maxDiscount = _number(data['maxDiscount'], double.infinity);
      if (maxDiscount.isFinite && maxDiscount > 0) {
        discount = discount.clamp(0, maxDiscount);
      }
    } else {
      throw Exception('Unsupported discount type.');
    }
    return discount.clamp(0, subtotal).toDouble();
  }

  Future<void> applyCoupon() async {
    final code = couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => couponMessage = 'Enter a coupon code.');
      return;
    }
    setState(() => isApplyingCoupon = true);
    try {
      final discount = await _calculateCouponDiscount(code);
      if (!mounted) return;
      setState(() {
        appliedCouponCode = code;
        discountAmount = discount;
        couponMessage =
            'Coupon applied! You saved ৳${discount.toStringAsFixed(0)}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        appliedCouponCode = null;
        discountAmount = 0;
        couponMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => isApplyingCoupon = false);
    }
  }

  void removeCoupon() {
    setState(() {
      appliedCouponCode = null;
      discountAmount = 0;
      couponController.clear();
      couponMessage = 'Coupon removed.';
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    couponController.dispose();
    transactionIdController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
    if (isSubmitting || !formKey.currentState!.validate()) return;
    if ((paymentMethod == 'bKash' || paymentMethod == 'Nagad') &&
        transactionIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your payment Transaction ID.'),
        ),
      );
      return;
    }
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
      // Re-check coupon immediately before placing the order.
      var finalDiscount = 0.0;
      if (appliedCouponCode != null) {
        try {
          finalDiscount = await _calculateCouponDiscount(appliedCouponCode!);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            appliedCouponCode = null;
            discountAmount = 0;
            couponMessage =
                'Coupon no longer valid. ${e.toString().replaceFirst('Exception: ', '')}';
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(couponMessage!)));
          return;
        }
      }

      final finalTotal =
          (subtotal - finalDiscount).clamp(0, double.infinity).toDouble() +
          deliveryFee;
      final items = widget.cart
          .map(
            (item) => <String, dynamic>{
              'foodId': item.food.id,
              'name': item.food.name,
              'category': item.food.category,
              'price': item.food.price,
              'quantity': item.quantity,
              'image': item.food.image,
              'itemTotal': item.food.price * item.quantity,
            },
          )
          .toList();

      final orderData = <String, dynamic>{
        'userId': user.uid,
        'customerName': nameController.text.trim(),
        'email': user.email ?? '',
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentMethod == 'Cash on Delivery'
            ? 'Cash on Delivery'
            : (paymentMethod == 'Card Payment (Demo)'
                  ? 'Demo Only'
                  : 'Pending Verification'),
        'transactionId': transactionIdController.text.trim(),
        'items': items,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'couponCode': appliedCouponCode ?? '',
        'discount': finalDiscount,
        'total': finalTotal,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final document = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      await NotificationService.createForUser(
        userId: user.uid,
        title: 'Order placed successfully',
        message:
            'Your order #${document.id.substring(0, document.id.length < 7 ? document.id.length : 7)} has been received.',
        type: 'order_placed',
        orderId: document.id,
      );
      if (!mounted) return;
      final savedName = nameController.text.trim();
      final savedPhone = phoneController.text.trim();
      final savedAddress = addressController.text.trim();
      final savedPaymentMethod = paymentMethod;
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
            total: finalTotal,
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
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter your name'
                  : null,
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
                if (phone.length < 8)
                  return 'Please enter a valid phone number';
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
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter your delivery address'
                  : null,
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE2D4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coupon & Discount',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: couponController,
                          textCapitalization: TextCapitalization.characters,
                          enabled:
                              appliedCouponCode == null && !isApplyingCoupon,
                          decoration: const InputDecoration(
                            hintText: 'Enter coupon code',
                            prefixIcon: Icon(Icons.local_offer_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (appliedCouponCode == null)
                        FilledButton(
                          onPressed: isApplyingCoupon ? null : applyCoupon,
                          child: isApplyingCoupon
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Apply'),
                        )
                      else
                        IconButton(
                          onPressed: removeCoupon,
                          tooltip: 'Remove coupon',
                          icon: const Icon(Icons.close, color: Colors.red),
                        ),
                    ],
                  ),
                  if (couponMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      couponMessage!,
                      style: TextStyle(
                        color: discountAmount > 0
                            ? Colors.green
                            : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
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
              value: 'bKash',
              groupValue: paymentMethod,
              title: const Text('bKash (Manual verification)'),
              secondary: const Icon(
                Icons.phone_android,
                color: Colors.deepPurple,
              ),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              value: 'Nagad',
              groupValue: paymentMethod,
              title: const Text('Nagad (Manual verification)'),
              secondary: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.deepOrange,
              ),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              value: 'Card Payment (Demo)',
              groupValue: paymentMethod,
              title: const Text('Card Payment (Demo only)'),
              subtitle: const Text('No real card charge will be made.'),
              secondary: const Icon(Icons.credit_card),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            if (paymentMethod == 'bKash' || paymentMethod == 'Nagad') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Send ৳${total.toStringAsFixed(2)} to the official merchant number provided by the app owner. Then enter the transaction ID below. Do not enter your PIN or OTP. Payment will remain Pending Verification until the merchant verifies it.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: transactionIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Payment Transaction ID',
                  hintText: 'Enter transaction ID',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            summaryRow('Subtotal', subtotal),
            summaryRow('Delivery Fee', deliveryFee),
            if (discountAmount > 0) summaryRow('Discount', -discountAmount),
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
              'bKash/Nagad entries are submitted for manual verification. Card Payment is demo-only; no real payment is processed.',
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
                  summaryTextRow(
                    'Payment Status',
                    paymentMethod == 'Cash on Delivery'
                        ? 'Cash on Delivery'
                        : (paymentMethod == 'Card Payment (Demo)'
                              ? 'Demo Only'
                              : 'Pending Verification'),
                  ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(orderId: orderId),
                  ),
                );
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Track My Order'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
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
