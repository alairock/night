import 'package:flutter/material.dart';
import 'package:night/models/game.dart';
import 'package:night/models/user.dart';
import 'package:night/screens/lobby_screen.dart';
import 'list_users.dart'; // Assuming this is the path to your list_users.dart
import 'package:night/utils/lobbyclasses.dart';

typedef LobbyBuilder = Function(
    Game game, Widget widget, List<User> users, Object user);

LobbyBuilder buildLobby({required HostUser hostUser}) {
  return (Game game, Widget widget, List<User> users, Object user) {
    if (users.length >= game.minPlayers && (widget as LobbyScreen).isHost) {
      // add button to start the game
      if (users.length > game.maxPlayers) {
        return Column(
          children: [
            Expanded(child: UserListBuilder.buildUserList(users, user)),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'You can have a maximum of 10 players in a game.',
                style: TextStyle(
                  color: Color(0xFFEF6639),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Expanded(child: UserListBuilder.buildUserList(users, user)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0XFFde6e46),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  hostUser.startGame();
                },
                child: const Text('Start Game'),
              ),
            ),
          ],
        );
      }
    }
    return Column(children: [
      Expanded(child: UserListBuilder.buildUserList(users, user))
    ]);
  };
}
