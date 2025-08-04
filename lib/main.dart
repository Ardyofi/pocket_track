import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// App colors
const mainColor = Color(0xFF667EEA);
const backgroundColor = Color(0xFFF8F9FA);
const textDark = Color(0xFF2D3436);
const textLight = Color(0xFF636E72);

// Predefined expense categories with their icons and colors
final expenseCategories = {
  'Food': (Icons.fastfood, Colors.orange),
  'Travel': (Icons.airplanemode_active, Colors.blue),
  'Shopping': (Icons.shopping_bag, Colors.purple),
  'Bills': (Icons.receipt_long, Colors.red),
  'Others': (Icons.miscellaneous_services, Colors.grey),
};

// Card decoration for balance card
final balanceCardDecoration = BoxDecoration(
  gradient: LinearGradient(
    colors: [Color.fromARGB(255, 227, 142, 255), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(20),
  boxShadow: [
    BoxShadow(
      color: mainColor.withOpacity(0.3),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ],
);

// Main function - app starts here
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive database
  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());
  
  // Open database boxes
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
  // Database boxes
  late Box accountsBox;
  late Box<Expense> expensesBox;
  
  // Current account name
  String currentAccountName = 'Default';

  @override
  void initState() {
    super.initState();
    // Get database boxes
    accountsBox = Hive.box('accountsBox');
    expensesBox = Hive.box<Expense>('expensesBox');

    // Get current account or set default
    currentAccountName = accountsBox.get('currentAccount', defaultValue: 'Default');

    // Create default account if it doesn't exist
    if (!accountsBox.containsKey(currentAccountName)) {
      accountsBox.put(currentAccountName, <dynamic>[]);
    }
  }

  // Get all expenses for current account
  List<Expense> getCurrentAccountExpenses() {
    // Get list of expense IDs for current account
    final expenseIds = accountsBox.get(currentAccountName) as List<dynamic>? ?? [];
    // Get actual expense objects from the IDs
    return expenseIds.map((id) => expensesBox.get(id)).whereType<Expense>().toList();
  }

  // Calculate total amount spent
  double calculateTotalExpenses() {
    return getCurrentAccountExpenses().fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get spending by category
  Map<String, double> getCategoryTotals() {
    var totals = <String, double>{};
    for (var expense in getCurrentAccountExpenses()) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  // Format date to show time ago (e.g., "2h ago", "Yesterday", "3d ago")
  String formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return diff.inHours == 0 ? '${diff.inMinutes}m ago' : '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  // Add new expense
  void addNewExpense(Expense newExpense) async {
    // Save expense to database
    final expenseKey = await expensesBox.add(newExpense);
    
    // Add expense key to current account
    final currentExpenseKeys = List<dynamic>.from(accountsBox.get(currentAccountName) ?? <dynamic>[]);
    currentExpenseKeys.insert(0, expenseKey); // Add to beginning of list
    await accountsBox.put(currentAccountName, currentExpenseKeys);
    
    // Refresh the screen
    setState(() {});
  }

  // Remove single expense
  void removeExpense(int expenseIndex) async {
    final expenseKeys = List<dynamic>.from(accountsBox.get(currentAccountName) ?? <dynamic>[]);
    if (expenseIndex < expenseKeys.length) {
      // Delete expense from database
      final keyToDelete = expenseKeys[expenseIndex];
      await expensesBox.delete(keyToDelete);
      
      // Remove key from account list
      expenseKeys.removeAt(expenseIndex);
      await accountsBox.put(currentAccountName, expenseKeys);
      
      // Refresh the screen
      setState(() {});
    }
  }

  // Switch to different account
  void switchToAccount(String accountName) {
    setState(() {
      currentAccountName = accountName;
      accountsBox.put('currentAccount', currentAccountName);
      
      // Create account if it doesn't exist
      if (!accountsBox.containsKey(currentAccountName)) {
        accountsBox.put(currentAccountName, <dynamic>[]);
      }
    });
  }

  // Delete an account
  void deleteAccount(String accountName) async {
    if (accountName == 'Default') return; // Don't delete default account
    
    // Delete all expenses in this account
    final expenseKeys = List<dynamic>.from(accountsBox.get(accountName) ?? <dynamic>[]);
    for (var key in expenseKeys) {
      await expensesBox.delete(key);
    }
    
    // Remove the account
    await accountsBox.delete(accountName);
    
    // Switch to default if we deleted current account
    if (currentAccountName == accountName) {
      switchToAccount('Default');
    } else {
      setState(() {});
    }
  }

  // Delete all expenses in current account
  void deleteAllExpenses() async {
    final expenseKeys = List<dynamic>.from(accountsBox.get(currentAccountName) ?? <dynamic>[]);
    for (var key in expenseKeys) {
      await expensesBox.delete(key);
    }
    await accountsBox.put(currentAccountName, <dynamic>[]);
    setState(() {});
  }

  // Show add expense screen
  void showAddExpenseScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseScreen(onAddExpense: addNewExpense),
    );
  }

  // Show account manager screen
  void showAccountManagerScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountManagerScreen(
        currentAccount: currentAccountName,
        onSwitchAccount: switchToAccount,
        onDeleteAccount: deleteAccount,
        accountsBox: accountsBox,
        expensesBox: expensesBox,
      ),
    );
  }

  // Show confirmation dialog with custom title and action
  Future<void> showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
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
  }

  // Show delete all expenses dialog
  void showDeleteAllExpensesDialog() {
    var expenses = getCurrentAccountExpenses();
    if (expenses.isEmpty) return;
    
    showConfirmDialog(
      title: 'Delete All Expenses?',
      content: 'Are you sure you want to delete all ${expenses.length} expenses from "$currentAccountName"? This action cannot be undone.',
      onConfirm: deleteAllExpenses,
    );
  }

  // Show delete single expense dialog
  void showDeleteExpenseDialog(Expense expense, int index) {
    showConfirmDialog(
      title: 'Delete Expense?',
      content: 'Are you sure you want to delete "${expense.title}"?',
      onConfirm: () => removeExpense(index),
    );
  }

  // Build the balance card widget
  Widget buildBalanceCard() => Container(
    margin: EdgeInsets.all(20),
    padding: EdgeInsets.all(24),
    decoration: balanceCardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Expenses', 
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
        SizedBox(height: 8),
        Text('\€${calculateTotalExpenses().toStringAsFixed(2)}',
          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        Row(children: [
          Icon(Icons.trending_up, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('This account', 
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
        ]),
      ],
    ),
  );

  // Build category stats widget
  Widget buildCategoryStats() {
    var totals = getCategoryTotals();
    if (totals.isEmpty) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: totals.entries.take(3).map((e) => Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              )],
            ),
            child: Column(children: [
              Text(e.key, style: TextStyle(
                fontSize: 12, color: textLight, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('\€${e.value.toStringAsFixed(0)}', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            ]),
          ),
        )).toList(),
      ),
    );
  }

  // Build expenses list widget
  Widget buildExpensesList() {
    List<Expense> expenses = getCurrentAccountExpenses();
    
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ),
            
            // Expenses list or empty state
            Expanded(
              child: expenses.isEmpty
                  ? buildEmptyExpensesWidget()
                  : buildExpensesListView(expenses),
            ),
          ],
        ),
      ),
    );
  }

  // Empty state widget
  Widget buildEmptyExpensesWidget() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
        SizedBox(height: 16),
        Text('No expenses yet',
          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Text('Tap the + button to add your first expense',
          style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ],
    ),
  );

  // List of expenses
  Widget buildExpensesListView(List<Expense> expenses) => ListView.builder(
    padding: EdgeInsets.symmetric(horizontal: 20),
    itemCount: expenses.length,
    itemBuilder: (_, i) => buildExpenseItem(expenses[i], i),
  );

  // Single expense item
  Widget buildExpenseItem(Expense e, int index) => Dismissible(
    key: Key('expense_${e.hashCode}_$index'),
    direction: DismissDirection.endToStart,
    background: Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 20),
      child: Icon(Icons.delete, color: Colors.white),
    ),
    confirmDismiss: (_) => showSwipeDeleteConfirmation(e),
    onDismissed: (_) => removeExpense(index),
    child: GestureDetector(
      onLongPress: () => showDeleteExpenseDialog(e, index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(children: [
          // Icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: e.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(e.icon, color: e.color, size: 24),
          ),
          SizedBox(width: 16),
          
          // Title and category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
                SizedBox(height: 4),
                Text(e.category,
                  style: TextStyle(fontSize: 14, color: textLight)),
              ],
            ),
          ),
          
          // Amount and date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-\€${e.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              SizedBox(height: 4),
              Text(formatTimeAgo(e.date),
                style: TextStyle(fontSize: 12, color: textLight)),
            ],
          ),
          SizedBox(width: 8),
          
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
            onPressed: () => showDeleteExpenseDialog(e, index),
            tooltip: 'Delete expense',
          ),
        ]),
      ),
    ),
  );


  // Show swipe delete confirmation
  Future<bool?> showSwipeDeleteConfirmation(Expense expense) async {
  return await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Delete?'),
          content: Text('Delete "${expense.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Yes')),
          ],
        ),
      ) ??
      false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Welcome, $currentAccountName'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (selectedOption) {
              if (selectedOption == 'accounts') {
                showAccountManagerScreen();
              } else if (selectedOption == 'delete_all') {
                showDeleteAllExpensesDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Accounts'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete All Expenses',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            buildBalanceCard(),
            buildCategoryStats(),
            SizedBox(height: 20),
            buildExpensesList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddExpenseScreen,
        backgroundColor: Color(0xFF667EEA),
        child: Icon(Icons.add),
      ),
    );
  }
}

// Account Manager Screen
class AccountManagerScreen extends StatefulWidget {
  final String currentAccount;
  final Function(String) onSwitchAccount;
  final Function(String) onDeleteAccount;
  final Box accountsBox;
  final Box<Expense> expensesBox;

  AccountManagerScreen({
    required this.currentAccount,
    required this.onSwitchAccount,
    required this.onDeleteAccount,
    required this.accountsBox,
    required this.expensesBox,
  });

  @override
  _AccountManagerScreenState createState() => _AccountManagerScreenState();
}

class _AccountManagerScreenState extends State<AccountManagerScreen> {
  final TextEditingController newAccountController = TextEditingController();

  // Get all account names
  List<String> getAllAccountNames() {
    List<String> accountNames = [];
    for (var key in widget.accountsBox.keys) {
      if (key != 'currentAccount') {
        accountNames.add(key.toString());
      }
    }
    accountNames.sort();
    return accountNames;
  }

  // Get number of expenses in account
  int getExpenseCountForAccount(String accountName) {
    final expenseKeys = widget.accountsBox.get(accountName) as List<dynamic>?;
    return expenseKeys?.length ?? 0;
  }

  // Get total amount spent in account
  double getTotalAmountForAccount(String accountName) {
    final expenseKeys = widget.accountsBox.get(accountName) as List<dynamic>?;
    if (expenseKeys == null) return 0;
    
    double total = 0;
    for (var key in expenseKeys) {
      final expense = widget.expensesBox.get(key);
      if (expense != null) {
        total = total + expense.amount;
      }
    }
    return total;
  }

  // Create new account
  void createNewAccount() {
    String accountName = newAccountController.text.trim();
    if (accountName.isNotEmpty && !widget.accountsBox.containsKey(accountName)) {
      widget.accountsBox.put(accountName, <dynamic>[]);
      widget.onSwitchAccount(accountName);
      Navigator.pop(context);
    }
  }

  // Show delete account confirmation
  void showDeleteAccountConfirmation(String accountName) {
    if (accountName == 'Default') return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account?'),
        content: Text('Are you sure you want to delete "$accountName" and all its expenses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDeleteAccount(accountName);
              Navigator.pop(context);
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
  }

  @override
  Widget build(BuildContext context) {
    List<String> accountNames = getAllAccountNames();
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
            SizedBox(height: 16),
            
            // Title
            Text(
              'Manage Accounts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Create new account section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newAccountController,
                    decoration: InputDecoration(
                      hintText: 'Enter new account name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: createNewAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            Text(
              'Existing Accounts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            
            // Accounts list
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: accountNames.length,
                itemBuilder: (context, index) {
                  String accountName = accountNames[index];
                  bool isCurrentAccount = accountName == widget.currentAccount;
                  int expenseCount = getExpenseCountForAccount(accountName);
                  double totalAmount = getTotalAmountForAccount(accountName);
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrentAccount 
                          ? Color(0xFF667EEA).withOpacity(0.1) 
                          : Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrentAccount 
                          ? Border.all(color: Color(0xFF667EEA)) 
                          : null,
                    ),
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(
                            accountName,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (isCurrentAccount) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFF667EEA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Current',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('$expenseCount expenses • \€' + totalAmount.toStringAsFixed(2)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Switch account button
                          if (!isCurrentAccount)
                            IconButton(
                              icon: Icon(Icons.switch_account, color: Color(0xFF667EEA)),
                              onPressed: () {
                                widget.onSwitchAccount(accountName);
                                Navigator.pop(context);
                              },
                            ),
                          // Delete account button
                          if (accountName != 'Default')
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showDeleteAccountConfirmation(accountName),
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
    );
  }
}

// Add Expense Screen
// Screen for adding new expenses
class AddExpenseScreen extends StatefulWidget {
  final Function(Expense) onAddExpense;
  
  AddExpenseScreen({required this.onAddExpense});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final amountController = TextEditingController();

  String selectedCategory = 'Food';
  DateTime selectedDate = DateTime.now();

  // Get icon and color for selected category
  IconData get categoryIcon => expenseCategories[selectedCategory]!.$1;
  Color get categoryColor => expenseCategories[selectedCategory]!.$2;

  // Submit new expense
  void submitExpense() {
    if (formKey.currentState!.validate()) {
      final newExpense = Expense(
        title: titleController.text,
        amount: double.parse(amountController.text),
        category: selectedCategory,
        icon: categoryIcon,
        color: categoryColor,
        date: selectedDate,
      );
      widget.onAddExpense(newExpense);
      Navigator.pop(context);
    }
  }

  // Pick date
  Future<void> pickExpenseDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Wrap(
            runSpacing: 12,
            children: [
              // Handle bar
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
              
              // Title
              Text(
                'Add Expense',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              
              // Expense title input
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (inputValue) {
                  if (inputValue == null || inputValue.isEmpty) {
                    return 'Enter title';
                  }
                  return null;
                },
              ),
              
              // Amount input
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (inputValue) {
                  if (inputValue == null || inputValue.isEmpty) {
                    return 'Enter amount';
                  }
                  if (double.tryParse(inputValue) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              
              // Category dropdown
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items: expenseCategories.keys.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(expenseCategories[category]!.$1, 
                             color: expenseCategories[category]!.$2),
                        SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newCategory) {
                  if (newCategory != null) {
                    setState(() => selectedCategory = newCategory);
                  }
                },
              ),
              
              // Date picker
              Row(
                children: [
                  Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                  Spacer(),
                  TextButton(
                    onPressed: pickExpenseDate,
                    child: Text('Select Date'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Submit button
              ElevatedButton(
                onPressed: submitExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
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

// Expense data model
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

// Expense database adapter
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