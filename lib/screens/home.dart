import 'package:flutter/material.dart';
import 'package:splitwise/widgets/add_expenses.dart';
import 'package:splitwise/widgets/add_group.dart';
import 'package:splitwise/widgets/balance_screen.dart';
import 'package:splitwise/widgets/expenses_list.dart';
import 'package:splitwise/widgets/group_list.dart';
import 'package:splitwise/widgets/user_profile.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    ExpensesList(),
    GroupsList(),
    BalanceScreen(),
    UserProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onAddButtonPressed() {
    if (_selectedIndex == 0) {
      showDialog(
        context: context,
        builder: (context) => AddExpenseScreen(),
      );
    } else if (_selectedIndex == 1) {
      showDialog(
        context: context,
        builder: (context) => AddGroupScreen(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitwise'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: _selectedIndex != 2
          ? FloatingActionButton(
              onPressed: _onAddButtonPressed,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.wallet),
            label: 'Balance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
