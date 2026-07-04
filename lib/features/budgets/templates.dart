/// Life-stage starter budgets. Values are in rupees; multiply by 100 for paise.
/// Category names must match the seeded expense categories.
class BudgetTemplate {
  const BudgetTemplate(this.name, this.blurb, this.rupees);
  final String name;
  final String blurb;
  final Map<String, int> rupees;

  /// Allocation map in minor units (paise), keyed by category name.
  Map<String, int> get minor =>
      rupees.map((k, v) => MapEntry(k, v * 100));
}

const kBudgetTemplates = <BudgetTemplate>[
  BudgetTemplate('Student', 'Lean monthly plan (~₹15k)', {
    'Food': 4000,
    'Groceries': 1500,
    'Transport': 1500,
    'Education': 2000,
    'Fun': 1500,
    'Shopping': 1500,
    'Bills': 1000,
    'Health': 1000,
  }),
  BudgetTemplate('Professional', 'Working single (~₹45k)', {
    'Rent': 15000,
    'Food': 8000,
    'Groceries': 4000,
    'Transport': 4000,
    'Bills': 4000,
    'Shopping': 4000,
    'Fun': 3000,
    'Health': 2000,
    'Travel': 1000,
  }),
  BudgetTemplate('Family', 'Household (~₹70k)', {
    'Rent': 20000,
    'Groceries': 12000,
    'Food': 8000,
    'Bills': 8000,
    'Transport': 5000,
    'Health': 5000,
    'Education': 5000,
    'Shopping': 4000,
    'Fun': 3000,
  }),
];
