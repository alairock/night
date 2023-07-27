import 'package:flutter/material.dart';
import 'package:mob/screens/lobby_screen.dart';
import 'package:mob/utils/lobby.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({Key? key}) : super(key: key);

  @override
  NewGameScreenState createState() => NewGameScreenState();
}

class NewGameScreenState extends State<NewGameScreen> {
  late TextEditingController usernameController;
  String userId = "";
  String username = "";

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController();
    loadUserData();
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? "";
    userId = prefs.getString('userId') ?? "";

    if (username.isNotEmpty && userId.isNotEmpty) {
      setState(() {
        usernameController.text = username;
      });
    } else {
      usernameController.text = "";
    }
  }

  Future<void> updateUsername(String username) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);

    if (userId.isEmpty) {
      // Get a random id for the user
      userId = generateRandomCode(32);
      await prefs.setString('userId', userId);
    } else {
      // If user exists, update the username
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lobby"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: usernameController,
              onChanged: (value) {
                updateUsername(value);
                setState(() {}); // triggers UI refresh
              },
              decoration: const InputDecoration(
                labelText: "Username",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: usernameController.text.isEmpty
                  ? null
                  : () async {
                      var navigator = Navigator.of(context);
                      String gameCode = generateRandomCode(5);
                      if (username == "arst") {
                        gameCode = "arst";
                      }
                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => LobbyScreen(
                              gameCode: gameCode,
                              name: usernameController.text,
                              isHost: true),
                        ),
                      );
                    },
              child: const Text("New Game"),
            ),
            ElevatedButton(
              onPressed: usernameController.text.isEmpty
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final TextEditingController codeController =
                              TextEditingController();

                          return AlertDialog(
                            title: const Text("Enter Code"),
                            content: TextField(
                              controller: codeController,
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () async {
                                  var navigator = Navigator.of(context);
                                  String enteredCode = codeController.text;
                                  navigator.push(
                                    MaterialPageRoute(
                                      builder: (context) => LobbyScreen(
                                          gameCode: enteredCode,
                                          name: usernameController.text,
                                          isHost: false),
                                    ),
                                  );
                                },
                                child: const Text("Join"),
                              ),
                            ],
                          );
                        },
                      );
                    },
              child: const Text("Join Game"),
            ),
          ],
        ),
      ),
    );
  }
}
