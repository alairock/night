import 'dart:async';
import 'package:flutter/material.dart';
import 'package:night/models/user.dart';
import 'package:night/utils/lobby.dart';
import 'package:night/utils/lobbyclasses.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LobbyScreen extends StatefulWidget {
  final String gameCode;
  final bool isHost;
  final String name;

  const LobbyScreen({
    Key? key,
    required this.gameCode,
    required this.name,
    required this.isHost,
  }) : super(key: key);

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late StreamController<List<User>> _controller;
  late Object user; // This can be either HostUser or NormalUser

  @override
  void initState() {
    super.initState();
    _controller = StreamController<List<User>>.broadcast();
    if (widget.isHost) {
      user = HostUser(widget.name, widget.gameCode, _controller);
    } else {
      user = NormalUser(
          widget.name, widget.gameCode, _controller, onHostDisconnected);
    }
  }

  void onHostDisconnected() {
    Fluttertoast.showToast(
      msg: 'You have been disconnected from the game.',
      gravity: ToastGravity.TOP_LEFT,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
    Navigator.of(context).pop(); // Navigate back from the Lobby screen
  }

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }

    if (user is HostUser) {
      HostUser hu = user as HostUser;
      if (hu.isAdding) {
        Timer(Duration(seconds: 1), () {
          hu.dispose();
        });
      } else {
        hu.dispose();
      }
      (user as HostUser).dispose();
    } else {
      NormalUser nu = user as NormalUser;
      if (nu.isAdding) {
        Timer(Duration(seconds: 1), () {
          nu.dispose();
        });
      } else {
        nu.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => onBackButtonPressed(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lobby: ${widget.gameCode}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              onBackButtonPressed(context).then((_) {
                Navigator.of(context).pop();
              });
            },
          ),
        ),
        body: StreamBuilder<List<User>>(
          stream: _controller.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!;
            // check length of users
            if (users.length >= 2 && widget.isHost) {
              // add button to start the game
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(users[index].name),
                        tileColor: users[index].isHost
                            ? Color.fromARGB(255, 239, 239, 239)
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        (user as HostUser).startGame();
                      },
                      child: const Text('Start Game'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(users[index].name),
                tileColor: users[index].isHost
                    ? Color.fromARGB(255, 239, 239, 239)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
