import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:night/models/game.dart';
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
  List<User> users = [];
  late Object user; // This can be either HostUser or NormalUser
  late Game game;
  late GameState gameState;
  bool gameStarted = false; // Step 1: Add the gameStarted variable.

  @override
  void initState() {
    super.initState();
    _controller = StreamController<List<User>>.broadcast();
    // add test users to the stream
    game = Game(
        id: widget.gameCode,
        isStarted: false,
        startGameCallback: startGame,
        endGameCallback: endGame,
        updateStateCallback: updateGameState);
    gameState = GameState(false, false, [], "");
    if (widget.isHost) {
      user = HostUser(widget.name, widget.gameCode, _controller, game);
    } else {
      user = NormalUser(
          widget.name, widget.gameCode, _controller, onHostDisconnected, game);
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
        Timer(const Duration(seconds: 1), () {
          hu.dispose();
        });
      } else {
        hu.dispose();
      }
      (user as HostUser).dispose();
    } else {
      NormalUser nu = user as NormalUser;
      if (nu.isAdding) {
        Timer(const Duration(seconds: 1), () {
          nu.dispose();
        });
      } else {
        nu.dispose();
      }
    }
    super.dispose();
  }

  void startGame() {
    setState(() {
      gameStarted = true;
    });
  }

  void endGame() {
    setState(() {
      gameStarted = false;
    });
  }

  void updateGameState(GameState gs) {
    print("updateGameState: $gs");
    if (!gameStarted) {
      setState(() {
        gameStarted = true;
        gameState = gs;
      });
      return;
    }
    setState(() {
      gameState = gs;
    });
  }

  StreamBuilder _buildLobbyStream() {
    return StreamBuilder<List<User>>(
      stream: _controller.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final _users = snapshot.data!;
        users = _users;
        if (!gameStarted && !game.isStarted) {
          return _buildLobby(game, widget, _users, user);
        } else {
          return _buildGameScreen(gameState);
        }
      },
    );
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
        body: () {
          if (!gameStarted && !game.isStarted) {
            return _buildLobbyStream();
          } else {
            return _buildGameScreen(gameState, users, user);
          }
        }(),
      ),
    );
  }
}

Function _buildGameScreen =
    (GameState gameState, List<User> users, Object user) {
  // create a map of user id to user name
  Map<String, String> userIdToName = {};
  for (var user in users) {
    userIdToName[user.id] = user.name;
  }

  return Column(
    children: [
      for (var u in users)
        if (u.id == (user as HostUser).id)
          Text(
              "${userIdToName[u.id]}: ${gameState.isHitler ? "Hitler" : gameState.isFascist ? "Fascist" : "Liberal"}")
        else if (u.id == gameState.hitlerId)
          Text(
              "${userIdToName[u.id]}: Hitler ${u.id == (user as HostUser).id ? '(You)' : ''}")
        else if (gameState.otherFascists.contains(u.id))
          Text(
              "${userIdToName[u.id]}: Fascist ${u.id == (user as HostUser).id ? '(You)' : ''}")
        else
          Text(
              "${userIdToName[u.id]}: Liberal ${u.id == (user as HostUser).id ? '(You)' : ''}"),

      // add button to end the game if the user is the host
      if (user is HostUser)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              user.endGame();
            },
            child: const Text('End Game'),
          ),
        ),
    ],
  );
};

// function for _buildLobby(users);
Function _buildLobby =
    (Game game, LobbyScreen widget, List<User> users, Object user) {
  if (users.length >= game.minPlayers && widget.isHost) {
    // add button to start the game
    if (users.length > game.maxPlayers) {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(users[index].name),
                tileColor: users[index].isHost
                    ? const Color.fromARGB(255, 239, 239, 239)
                    : null,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'You can have a maximum of 10 players in a game.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(users[index].name),
                tileColor: users[index].isHost
                    ? const Color.fromARGB(255, 239, 239, 239)
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
  }
  return ListView.builder(
    itemCount: users.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(users[index].name),
      tileColor:
          users[index].isHost ? const Color.fromARGB(255, 239, 239, 239) : null,
    ),
  );
};
