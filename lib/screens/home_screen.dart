// home_screen.dart

import 'package:flutter/material.dart';
import 'main_scaffold.dart'; // Import the new main file (where your state and navigation logic lives)

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // HomeScreen now simply returns the MainScaffold, which handles
    // the bottom navigation and body switching.
    return const MainScaffold();
  }
}