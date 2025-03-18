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
  static const List<String> _titles = <String>[
    'Expenses',
    'Groups',
    'Balance',
    'Profile',
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title:  Text(_titles[_selectedIndex], style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: _selectedIndex != 2 && _selectedIndex != 3
          ? FloatingActionButton(
              onPressed: _onAddButtonPressed,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            backgroundColor: const Color(0xFF1E1E1E),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.wallet),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: '',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            elevation: 10,
          ),
        ),
      ),
    );
  }
}
