import 'package:flutter_test/flutter_test.dart';
import 'package:food_ordering_app/main.dart';

void main() {
  test('FoodOrderingApp can be created', () {
    const app = FoodOrderingApp();
    expect(app, isA<FoodOrderingApp>());
  });
}
