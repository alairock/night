import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: SwitchListTile(
        title: const Text('Dark Mode'),
        value: true, // you'll replace this with your own state management
        onChanged: (bool value) {
          // Implement your logic to handle dark mode here
        },
      ),
    );
  }
}
