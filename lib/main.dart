import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(ExpenseAdapter());

  await Hive.openBox('accountsBox');
  await Hive.openBox<Expense>('expensesBox');

  runApp(MaterialApp(
    title: 'Expense Tracker',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'SF Pro Display',
    ),
    debugShowCheckedModeBanner: false,
    home: ExpenseTrackerApp(),
  ));
}

class ExpenseTrackerApp extends StatefulWidget {
  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late Box accountsBox;
  late Box<Expense> expensesBox;

  String currentAccount = 'Default';

  @override
  void initState() {
    super.initState();
    accountsBox = Hive.box('accountsBox');
    expensesBox = Hive.box<Expense>('expensesBox');

    currentAccount = accountsBox.get('currentAccount', defaultValue: 'Default');

    if (!accountsBox.containsKey(currentAccount)) {
      accountsBox.put(currentAccount, <dynamic>[]);
    }
  }

  List<Expense> get currentExpenses {
    final List<dynamic>? rawList = accountsBox.get(currentAccount);
    if (rawList == null) return [];
    return rawList.map((key) => expensesBox.get(key)).where((expense) => expense != null).cast<Expense>().toList();
  }

  void _addExpense(Expense expense) async {
    final key = await expensesBox.add(expense);
    final List<dynamic> keys = List<dynamic>.from(accountsBox.get(currentAccount) ?? <dynamic>[]);
    keys.insert(0, key);
    await accountsBox.put(currentAccount, keys);
    setState(() {});
  }

  void _removeExpense(int index) async {
    final List<dynamic> keys = List<dynamic>.from(accountsBox.get(currentAccount) ?? <dynamic>[]);
    if (index < keys.length) {
      final keyToDelete = keys[index];
      await expensesBox.delete(keyToDelete);
      keys.removeAt(index);
      await accountsBox.put(currentAccount, keys);
      setState(() {});
    }
  }

  void _switchAccount(String newAccount) {
    setState(() {
      currentAccount = newAccount;
      accountsBox.put('currentAccount', currentAccount);
      if (!accountsBox.containsKey(currentAccount)) {
        accountsBox.put(currentAccount, <dynamic>[]);
      }
    });
  }

  void _showAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseModal(onAddExpense: _addExpense),
    );
  }

  void _showSwitchAccountDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Switch Account'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter account name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _switchAccount(name);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF667EEA),
              foregroundColor: Colors.white,
            ),
            child: Text('Switch'),
          ),
        ],
      ),
    );
  }

  double get totalExpenses {
    return currentExpenses.fold(0, (sum, exp) => sum + exp.amount);
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};
    for (var expense in currentExpenses) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return '${diff.inHours}h ago';
      }
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Expense Tracker - $currentAccount'),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_account),
            onPressed: _showSwitchAccountDialog,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Balance Card
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Expenses',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      )),
                  SizedBox(height: 8),
                  Text('\$${totalExpenses.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'This account',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 14),
                      )
                    ],
                  )
                ],
              ),
            ),

            // Quick stats (categories)
            if (categoryTotals.isNotEmpty)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: categoryTotals.entries.take(3).map((entry) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF636E72),
                                  fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text('\$${entry.value.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3436))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            SizedBox(height: 20),

            // Recent transactions
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Transactions',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3436)),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'See All',
                              style: TextStyle(
                                  color: Color(0xFF667EEA),
                                  fontWeight: FontWeight.w600),
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: currentExpenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, 
                                       size: 64, 
                                       color: Colors.grey[400]),
                                  SizedBox(height: 16),
                                  Text(
                                    'No expenses yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to add your first expense',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              itemCount: currentExpenses.length,
                              itemBuilder: (context, index) {
                                final expense = currentExpenses[index];
                                return GestureDetector(
                                  onLongPress: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text('Delete Expense?'),
                                        content: Text(
                                            'Are you sure you want to delete "${expense.title}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              _removeExpense(index);
                                              Navigator.pop(context);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: expense.color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            expense.icon,
                                            color: expense.color,
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                expense.title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2D3436),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                expense.category,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF636E72),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '-\$${expense.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              _formatDate(expense.date),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF636E72),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseModal,
        backgroundColor: Color(0xFF667EEA),
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddExpenseModal extends StatefulWidget {
  final Function(Expense) onAddExpense;

  AddExpenseModal({required this.onAddExpense});

  @override
  _AddExpenseModalState createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedCategory = 'Food';
  IconData _selectedIcon = Icons.fastfood;
  Color _selectedColor = Colors.orange;
  DateTime _selectedDate = DateTime.now();

  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Travel': Icons.airplanemode_active,
    'Shopping': Icons.shopping_bag,
    'Bills': Icons.receipt_long,
    'Others': Icons.miscellaneous_services,
  };

  final Map<String, Color> categoryColors = {
    'Food': Colors.orange,
    'Travel': Colors.blue,
    'Shopping': Colors.purple,
    'Bills': Colors.red,
    'Others': Colors.grey,
  };

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final expense = Expense(
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        icon: _selectedIcon,
        color: _selectedColor,
        date: _selectedDate,
      );
      widget.onAddExpense(expense);
      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding for keyboard
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 12,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text('Add Expense',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType:
                    TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter amount';
                  if (double.tryParse(val) == null)
                    return 'Enter valid number';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items: categoryIcons.keys
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedIcon = categoryIcons[val]!;
                      _selectedColor = categoryColors[val]!;
                    });
                  }
                },
              ),
              Row(
                children: [
                  Text(
                      'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                  Spacer(),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text('Select Date'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final IconData icon;

  @HiveField(4)
  final Color color;

  @HiveField(5)
  final DateTime date;

  Expense({
    required this.title,
    required this.amount,
    required this.category,
    required this.icon,
    required this.color,
    required this.date,
  });
}

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    return Expense(
      title: reader.readString(),
      amount: reader.readDouble(),
      category: reader.readString(),
      icon: IconData(reader.readInt(), fontFamily: 'MaterialIcons'),
      color: Color(reader.readInt()),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer.writeString(obj.title);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.category);
    writer.writeInt(obj.icon.codePoint);
    writer.writeInt(obj.color.value);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
  }
}