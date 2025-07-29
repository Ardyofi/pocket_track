// Calculate total money spent
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Track',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false, // This removes the debug banner
      home: ExpenseTracker(),
    );
  }
}

// Simple expense class
class Expense {
  String title;
  double amount;
  String category;
  DateTime date;

  Expense({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  // Convert expense to Map (for saving)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.millisecondsSinceEpoch,
    };
  }

  // Create expense from Map (for loading)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
    );
  }
}

class ExpenseTracker extends StatefulWidget {
  @override
  _ExpenseTrackerState createState() => _ExpenseTrackerState();
}

class _ExpenseTrackerState extends State<ExpenseTracker> {
  // List to store all expenses
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    loadExpenses(); // Load saved expenses when app starts
  }

  // Save expenses to phone storage
  void saveExpenses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> expenseStrings = expenses.map((expense) {
      return jsonEncode(expense.toMap());
    }).toList();
    await prefs.setStringList('expenses', expenseStrings);
  }

  // Load expenses from phone storage
  void loadExpenses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? expenseStrings = prefs.getStringList('expenses');
    
    if (expenseStrings != null) {
      setState(() {
        expenses = expenseStrings.map((expenseString) {
          Map<String, dynamic> expenseMap = jsonDecode(expenseString);
          return Expense.fromMap(expenseMap);
        }).toList();
      });
    }
  }
  double getTotalAmount() {
    double total = 0;
    for (Expense expense in expenses) {
      total += expense.amount;
    }
    return total;
  }

  // Add new expense to the list
  void addExpense(Expense newExpense) {
    setState(() {
      expenses.add(newExpense);
    });
    saveExpenses(); // Save to phone storage
  }

  // Remove expense from the list
  void removeExpense(int index) {
    setState(() {
      expenses.removeAt(index);
    });
    saveExpenses(); // Save to phone storage
  }

  // Show dialog to add new expense
  void showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AddExpenseDialog(
        onAddExpense: addExpense,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Expenses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 227, 142, 255), 
                Color.fromARGB(255, 95, 61, 247)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Total amount card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 227, 142, 255), 
                  Color.fromARGB(255, 95, 61, 247)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(255, 95, 61, 247).withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Total Spent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '\€${getTotalAmount().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Expenses list
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No expenses yet!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Tap the + button to add one',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      Expense expense = expenses[index];
                      return                         Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color.fromARGB(255, 95, 61, 247),
                            child: Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(expense.title),
                          subtitle: Text(expense.category),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\€${expense.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Show confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Delete Expense?'),
                                      content: Text('Are you sure you want to delete this expense?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            removeExpense(index);
                                            Navigator.pop(context);
                                          },
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
      floatingActionButton: FloatingActionButton(
        onPressed: showAddExpenseDialog,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color.fromARGB(255, 95, 61, 247),
      ),
    );
  }
}

// Dialog to add new expense
class AddExpenseDialog extends StatefulWidget {
  final Function(Expense) onAddExpense;

  AddExpenseDialog({required this.onAddExpense});

  @override
  _AddExpenseDialogState createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String selectedCategory = 'Food';

  List<String> categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];

  void addExpense() {
    String title = titleController.text;
    String amountText = amountController.text;

    // Check if fields are not empty
    if (title.isEmpty || amountText.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Try to convert amount to number
    double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Create new expense
    Expense newExpense = Expense(
      title: title,
      amount: amount,
      category: selectedCategory,
      date: DateTime.now(),
    );

    // Add expense and close dialog
    widget.onAddExpense(newExpense);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Expense'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'What did you buy?',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: 'How much did it cost?',
              border: OutlineInputBorder(),
              prefixText: '\€',
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedCategory = newValue!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: addExpense,
          child: Text('Add'),
        ),
      ],
    );
  }
}