import 'dart:async';
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
  bool gameStarted = false;
  bool showRole = false;

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

  void updateShowRole() {
    setState(() {
      showRole = !showRole;
    });
  }

  void onHostDisconnected() {
    Fluttertoast.showToast(
      msg: 'You have been disconnected from the game.',
      gravity: ToastGravity.TOP_LEFT,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
    if (mounted) {
      Navigator.of(context).pop(); // Navigate back from the Lobby screen
    }
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
      showRole = false;
    });
  }

  void updateGameState(GameState gs) {
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/lobbycode.png",
                width: 150,
              ),
              const SizedBox(
                  width: 10), // Optional space between image and text
              Text(
                widget.gameCode,
                style: const TextStyle(
                  fontSize: 24.0, // Set this value to twice your desired size
                  fontWeight: FontWeight.w900, // Extra bold weight
                  color: Color(0xFFFEFEB5), // Set your required color
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2.0, 2.0), // Set the offset for the shadow
                      blurRadius: 0.0, // No feathering
                    ),
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2.5, 2.5), // Set the offset for the shadow
                      blurRadius: 0.0, // No feathering
                    ),
                    Shadow(
                      color: Colors.black,
                      offset: Offset(3.0, 3.0), // Set the offset for the shadow
                      blurRadius: 0.0, // No feathering
                    ),
                  ],
                ),
              ),
            ],
          ), //Text('Lobby: ${widget.gameCode}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              onBackButtonPressed(context).then((shouldPop) {
                if (shouldPop) {
                  Navigator.of(context).pop();
                }
              });
            },
          ),
        ),
        body: () {
          if (!gameStarted && !game.isStarted) {
            return _buildLobbyStream();
          } else {
            return _buildGameScreen(
                gameState, users, user, showRole, updateShowRole);
          }
        }(),
      ),
    );
  }
}

Function _buildGameScreen = (GameState gameState, List<User> users, Object user,
    bool showRole, Function updateShowRole) {
  // create a map of user id to user name
  Map<String, String> userIdToName = {};
  for (var user in users) {
    userIdToName[user.id] = user.name;
  }

  String myId = "";
  if (user is HostUser) {
    myId = user.id;
  } else if (user is NormalUser) {
    myId = user.id;
  } else {
    return Container();
  }

  return Scrollbar(
      child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Center(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showRole)
                GestureDetector(
                    onTap: () {
                      updateShowRole();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Image.asset(
                        gameState.isHitler
                            ? "assets/hitler.jpg"
                            : gameState.isFascist
                                ? "assets/fascist.jpg"
                                : "assets/liberal.jpg",
                        width: 150,
                      ),
                    ))
              else
                GestureDetector(
                    onTap: () {
                      updateShowRole();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Image.asset(
                        "assets/secret.jpg",
                        width: 150,
                      ),
                    )),
              if (gameState.isFascist &&
                  gameState.otherFascists.isNotEmpty &&
                  showRole)
                // bold text
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text("Fellow Fascists:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              if (gameState.isFascist && showRole)
                for (var fa in gameState.otherFascists)
                  if (fa != myId)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          "• ${userIdToName[fa]} ${fa == myId ? '(You)' : ''}",
                        )),
              const Text(""),
              if (gameState.hitlerId != "" &&
                  gameState.hitlerId != myId &&
                  showRole)
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text("Hitler:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              if (gameState.hitlerId != "" &&
                  gameState.hitlerId != myId &&
                  showRole)
                Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      "• Hitler: ${userIdToName[gameState.hitlerId]}",
                    )),
              if (!showRole) const Text(""),
              // bold text
              if (!showRole)
                const Padding(
                  padding: EdgeInsets.only(bottom: 5),
                  child: Text("Sit in this order:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              if (!showRole)
                for (var u in users)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        "• ${userIdToName[u.id]} ${u.id == myId ? '(You)' : ''}",
                      )),
              if (user is HostUser)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: user.endGame,
                    child: const Text('End Game'),
                  ),
                ),
            ],
          ))));
};

LayoutBuilder _listUsers(List<User> users, Object user) {
  String myId = "";
  if (user is HostUser) {
    myId = user.id;
  } else if (user is NormalUser) {
    myId = user.id;
  } else {
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Container());
    });
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      double padding = 0;
      if (constraints.maxWidth > 800) {
        padding = constraints.maxWidth * 0.1; // 10% padding on either side
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Container(
              width: MediaQuery.of(context).size.width * 0.8,
              color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
              child: ListTile(
                leading:
                    users[index].isHost ? const Icon(Icons.king_bed) : null,
                title: Text(
                  user.name + (users[index].id == myId ? ' (You)' : ''),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Function _buildLobby =
    (Game game, LobbyScreen widget, List<User> users, Object user) {
  if (users.length >= game.minPlayers && widget.isHost) {
    // add button to start the game
    if (users.length > game.maxPlayers) {
      return Column(
        children: [
          Expanded(child: _listUsers(users, user)),
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
          Expanded(child: _listUsers(users, user)),
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
  return Column(children: [Expanded(child: _listUsers(users, user))]);
};
