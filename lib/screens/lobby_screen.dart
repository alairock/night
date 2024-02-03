import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:night/models/game.dart';
import 'package:night/models/user.dart';
import 'package:night/screens/game_screen.dart';
import 'package:night/screens/lobby.dart';
import 'package:night/utils/user_management.dart';

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
  late StreamController<List<User>> _controller =
      StreamController<List<User>>.broadcast();
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
    _buildLobbyStream();
    _initializeLobby();
  }

  void _buildLobbyStream() {
    _controller = StreamController<List<User>>.broadcast();
  }

  void _initializeLobby() {
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
      (user as HostUser).dispose();
    } else if (user is NormalUser) {
      (user as NormalUser).dispose();
    }
  }

  StreamBuilder<List<User>> _buildLobbyStreamBuilder() {
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
      Navigator.of(context).pop();
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
    setState(() {
      if (!gameStarted) {
        gameStarted = true;
      }
      gameState = gs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildLobbyStreamBuilder(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFEF6639),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/lobbycode.png", width: 150),
          const SizedBox(width: 10),
          SelectableText(widget.gameCode,
              style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFEFEB5))),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          final shouldPop = await _handleBackButtonPress();
          if (mounted && shouldPop) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<bool> _handleBackButtonPress() async {
    final shouldPop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm'),
            content: const Text('Do you really want to leave the lobby?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('No')),
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Yes')),
            ],
          ),
        ) ??
        false;
    return shouldPop;
  }
}
