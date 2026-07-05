import 'package:flutter/material.dart';

/// Icons are stored in the DB as string keys (not raw codepoints) so Flutter's
/// icon tree-shaking keeps working. Look up a const [IconData] by key here.
const Map<String, IconData> kAppIcons = {
  'food': Icons.restaurant,
  'transport': Icons.directions_bus,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'health': Icons.favorite,
  'fun': Icons.movie,
  'groceries': Icons.local_grocery_store,
  'rent': Icons.home,
  'education': Icons.school,
  'travel': Icons.flight,
  'gifts': Icons.card_giftcard,
  'salary': Icons.payments,
  'business': Icons.storefront,
  'interest': Icons.savings,
  'other': Icons.category,
  'cash': Icons.account_balance_wallet,
  'bank': Icons.account_balance,
  'card': Icons.credit_card,
  'wallet': Icons.wallet,
  // Savings-goal icons.
  'savings': Icons.savings,
  'goal': Icons.flag,
  'phone': Icons.smartphone,
  'car': Icons.directions_car,
  'house': Icons.house,
  'vacation': Icons.beach_access,
  'emergency': Icons.emergency,
  'wedding': Icons.favorite_border,
  'gadget': Icons.devices,
  'gift': Icons.card_giftcard,
  'star': Icons.star,
};

/// Icon keys offered when creating a savings goal.
const List<String> kGoalIconKeys = [
  'savings', 'goal', 'phone', 'car', 'house', 'vacation',
  'emergency', 'wedding', 'gadget', 'gift', 'star', 'travel',
];

IconData iconFor(String key) => kAppIcons[key] ?? Icons.category;
