import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:night/utils/user_management.dart';
import 'package:night/models/game.dart';
import 'package:night/models/user.dart';
import 'package:night/screens/game_screen.dart';
import 'package:night/screens/lobby.dart';
import 'package:night/utils/lobby.dart';

class LobbyScreen extends StatefulWidget {
  final String gameCode;
  final bool isHost;
  final String name;

  const LobbyScreen({
    super.key,
    required this.gameCode,
    required this.name,
    required this.isHost,
  });

  @override
  LobbyScreenState createState() => LobbyScreenState();
}

class LobbyScreenState extends State<LobbyScreen> {
  late StreamController<List<User>> _controller;
  List<User> users = [];
  late Object user; // This can be either HostUser or NormalUser
  late Game game;
  late GameState gameState;
  bool gameStarted = false;
  bool showRole = false;
  bool allowPop = true;

  @override
  void initState() {
    super.initState();
    _initializeLobby();
  }

  void _initializeLobby() {
    _controller = StreamController<List<User>>.broadcast();
    game = Game(
        id: widget.gameCode,
        isStarted: false,
        startGameCallback: startGame,
        endGameCallback: endGame,
        updateStateCallback: updateGameState);
    gameState = GameState(false, false, [], "");
    user = widget.isHost
        ? HostUser(widget.name, widget.gameCode, _controller, game)
        : NormalUser(widget.name, widget.gameCode, _controller,
            onHostDisconnected, game);
  }

  @override
  void dispose() {
    _controller.close();
    _disposeUser();
    super.dispose();
  }

  void _disposeUser() {
    if (user is HostUser) {
      _disposeHostUser();
    } else if (user is NormalUser) {
      _disposeNormalUser();
    }
  }

  void _disposeHostUser() {
    HostUser hu = user as HostUser;
    hu.dispose();
  }

  void _disposeNormalUser() {
    NormalUser nu = user as NormalUser;
    nu.dispose();
  }

  StreamBuilder<List<User>> _buildLobbyStream() {
    return StreamBuilder<List<User>>(
      stream: _controller.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        users = snapshot.data!;
        return gameStarted ? _buildGameScreen() : _buildLobby();
      },
    );
  }

  Widget _buildLobby() {
    LobbyBuilder lobbyBuilder = buildLobby(hostUser: user as AbstractUser);
    return lobbyBuilder(game, widget, users, user);
  }

  Widget _buildGameScreen() {
    GameScreenBuilder gameScreenBuilder = buildGameScreen(
      hostUser: user as AbstractUser,
    );
    return gameScreenBuilder(gameState, users, user, showRole, updateShowRole);
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
      backgroundColor: const Color(0xFFEF6639),
      textColor: Colors.white,
    );
    if (mounted) {
      Navigator.of(context).pop(); // Navigate back from the Lobby screen
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowPop,
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          await _handleBackButtonPress();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildLobbyStream(),
      ),
    );
  }

  Future<void> _handleBackButtonPress() async {
    final shouldPop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm'),
            content: const Text('Do you really want to leave the lobby?'),
            backgroundColor: const Color(0XFFDE6E46),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    setState(() {
      allowPop = shouldPop;
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFEF6639),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/lobbycode.png",
            width: 150,
          ),
          const SizedBox(width: 10), // Space between image and text
          Theme(
            data: Theme.of(context).copyWith(
                textSelectionTheme: const TextSelectionThemeData(
                    selectionColor: Colors.orange)),
            child: SelectableText(
              widget.gameCode,
              style: const TextStyle(
                fontSize: 24.0, // Size of the text
                fontWeight: FontWeight.w900, // Boldness of the text
                color: Color(0xFFFEFEB5), // Color of the text
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(2.0, 2.0), // Shadow offset
                    blurRadius: 0.0, // Shadow blur radius
                  ),
                  Shadow(
                    color: Colors.black,
                    offset: Offset(2.5, 2.5),
                    blurRadius: 0.0,
                  ),
                  Shadow(
                    color: Colors.black,
                    offset: Offset(3.0, 3.0),
                    blurRadius: 0.0,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          renderBackButtonModal(context).then((shouldPop) {
            if (shouldPop) {
              Navigator.of(context).pop();
            }
          });
        },
      ),
    );
  }
}
