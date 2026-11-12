import 'models.dart';

/// Where money comes from. Uses the [Category] shape so the same avatar and
/// chip widgets can show it.
const List<Category> incomeSources = [
  Category(id: 'allowance', name: 'Allowance', iconKey: 'allowance', colorValue: 0xFF2AA876, sortOrder: 0),
  Category(id: 'salary', name: 'Salary', iconKey: 'salary', colorValue: 0xFF2F8FD8, sortOrder: 1),
  Category(id: 'freelance', name: 'Freelance', iconKey: 'freelance', colorValue: 0xFF8A5CD6, sortOrder: 2),
  Category(id: 'gift', name: 'Gift', iconKey: 'gift', colorValue: 0xFFE24A8F, sortOrder: 3),
  Category(id: 'refund', name: 'Refund', iconKey: 'refund', colorValue: 0xFFEF7D3A, sortOrder: 4),
  Category(id: 'other_income', name: 'Other', iconKey: 'other_income', colorValue: 0xFF7A8296, sortOrder: 5),
];

final Map<String, Category> incomeSourceMap = {for (final s in incomeSources) s.id: s};
