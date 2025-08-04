# Pocket Track - Flutter Expense Tracker App Code Explanation

## Table of Contents
1. [Project Setup and Dependencies](#1-project-setup-and-dependencies)
2. [Constants and Configurations](#2-constants-and-configurations)
3. [Main Application Entry](#3-main-application-entry)
4. [Data Model](#4-data-model)
5. [Main App State](#5-main-app-state)
6. [Database Operations](#6-database-operations)
7. [UI Components](#7-ui-components)
8. [Screen Management](#8-screen-management)
9. [Utility Functions](#9-utility-functions)

## 1. Project Setup and Dependencies

```dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
```

These imports set up:
- Flutter Material Design widgets
- Hive database for local storage
- Hive Flutter adapter for widget integration

## 2. Constants and Configurations

### Color Scheme
```dart
const mainColor = Color(0xFF667EEA);
const backgroundColor = Color(0xFFF8F9FA);
const textDark = Color(0xFF2D3436);
const textLight = Color(0xFF636E72);
```
These define the app's color scheme:
- `mainColor`: Primary blue color
- `backgroundColor`: Light background
- `textDark`: Dark text color
- `textLight`: Light text color

### Expense Categories
```dart
final expenseCategories = {
  'Food': (Icons.fastfood, Colors.orange),
  'Travel': (Icons.airplanemode_active, Colors.blue),
  'Shopping': (Icons.shopping_bag, Colors.purple),
  'Bills': (Icons.receipt_long, Colors.red),
  'Others': (Icons.miscellaneous_services, Colors.grey),
};
```
Predefined expense categories with their icons and colors using tuples.

### Card Decoration
```dart
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
```
Defines the styling for the balance card with:
- Purple gradient background
- Rounded corners
- Subtle shadow effect

## 3. Main Application Entry

```dart
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
```

This main function:
1. Initializes Flutter bindings
2. Sets up Hive database
3. Registers expense data adapter
4. Opens database boxes for accounts and expenses
5. Launches the main app with Material Design theme

## 4. Data Model

### Expense Class
```dart
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
```

The Expense class represents an expense entry with:
- Title: Description of the expense
- Amount: Cost in currency
- Category: Type of expense
- Icon: Visual representation
- Color: Category color
- Date: When the expense occurred

### Database Adapter
```dart
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
```

This adapter handles:
- Converting Expense objects to binary for storage
- Reading binary data back into Expense objects

## 5. Main App State

### State Initialization
```dart
class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late Box accountsBox;
  late Box<Expense> expensesBox;
  String currentAccountName = 'Default';

  @override
  void initState() {
    super.initState();
    accountsBox = Hive.box('accountsBox');
    expensesBox = Hive.box<Expense>('expensesBox');
    currentAccountName = accountsBox.get('currentAccount', defaultValue: 'Default');
    if (!accountsBox.containsKey(currentAccountName)) {
      accountsBox.put(currentAccountName, <dynamic>[]);
    }
  }
}
```

This initializes:
- Database boxes for access
- Current account name
- Default account if none exists

## 6. Database Operations

### Getting Expenses
```dart
List<Expense> getCurrentAccountExpenses() {
  final expenseIds = accountsBox.get(currentAccountName) as List<dynamic>? ?? [];
  return expenseIds.map((id) => expensesBox.get(id)).whereType<Expense>().toList();
}
```
Retrieves all expenses for the current account by:
1. Getting expense IDs for the account
2. Mapping IDs to actual expense objects
3. Filtering out any null values

### Adding Expense
```dart
void addNewExpense(Expense newExpense) async {
  final expenseKey = await expensesBox.add(newExpense);
  final currentExpenseKeys = List<dynamic>.from(accountsBox.get(currentAccountName) ?? <dynamic>[]);
  currentExpenseKeys.insert(0, expenseKey);
  await accountsBox.put(currentAccountName, currentExpenseKeys);
  setState(() {});
}
```
Adds a new expense by:
1. Saving expense to database
2. Getting current expense list
3. Adding new expense key to start of list
4. Updating account's expense list
5. Refreshing UI

### Removing Expense
```dart
void removeExpense(int expenseIndex) async {
  final expenseKeys = List<dynamic>.from(accountsBox.get(currentAccountName) ?? <dynamic>[]);
  if (expenseIndex < expenseKeys.length) {
    final keyToDelete = expenseKeys[expenseIndex];
    await expensesBox.delete(keyToDelete);
    expenseKeys.removeAt(expenseIndex);
    await accountsBox.put(currentAccountName, expenseKeys);
    setState(() {});
  }
}
```
Removes an expense by:
1. Getting current expense list
2. Deleting expense from database
3. Removing expense key from list
4. Updating account's expense list
5. Refreshing UI

## 7. UI Components

### Balance Card
```dart
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
```
Creates a card showing:
- Total expenses amount
- Account indicator
- Gradient background
- Formatted currency value

### Category Stats
```dart
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
```
Shows category statistics:
- Top 3 spending categories
- Amount spent per category
- Clean card design with shadows

## 8. Screen Management

### Add Expense Screen
The `AddExpenseScreen` class provides:
- Form for expense details
- Category selection
- Date picker
- Input validation
- Submission handling

### Account Manager Screen
The `AccountManagerScreen` class handles:
- Account creation
- Account switching
- Account deletion
- Account statistics display

## 9. Utility Functions

### Time Formatting
```dart
String formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return diff.inHours == 0 ? '${diff.inMinutes}m ago' : '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}
```
Formats dates into readable relative time:
- Minutes for recent expenses
- Hours for same-day expenses
- "Yesterday" for 1-day old expenses
- Days for older expenses

### Category Totals
```dart
Map<String, double> getCategoryTotals() {
  var totals = <String, double>{};
  for (var expense in getCurrentAccountExpenses()) {
    totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
  }
  return totals;
}
```
Calculates total spending by category:
1. Creates empty totals map
2. Iterates through all expenses
3. Adds amount to category total
4. Returns category-wise totals
