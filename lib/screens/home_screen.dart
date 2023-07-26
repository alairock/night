import 'package:flutter/material.dart';
import 'new_game.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mob"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text("Play"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NewGameScreen()),
            );
          },
        ),
      ),
    );
  }
}
