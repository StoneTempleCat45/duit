import 'models.dart';

/// Seeded into the database the first time the app runs.
const List<Category> defaultCategories = [
  Category(id: 'food', name: 'Food', iconKey: 'food', colorValue: 0xFFEF7D3A, sortOrder: 0),
  Category(id: 'transport', name: 'Transport', iconKey: 'transport', colorValue: 0xFF2F8FD8, sortOrder: 1),
  Category(id: 'shopping', name: 'Shopping', iconKey: 'shopping', colorValue: 0xFFE24A8F, sortOrder: 2),
  Category(id: 'bills', name: 'Bills', iconKey: 'bills', colorValue: 0xFF8A5CD6, sortOrder: 3),
  Category(id: 'others', name: 'Others', iconKey: 'others', colorValue: 0xFF7A8296, sortOrder: 4),
];
