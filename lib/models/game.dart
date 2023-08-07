import 'package:night/models/user.dart';
import 'dart:math';

class GameState {
  late bool isHitler = false;
  late bool isFascist = false;
  late List otherFascists = [];
  late String hitlerId = "";

  GameState();

  Map<String, dynamic> toJson() => {
        'isHitler': isHitler,
        'isFascist': isFascist,
        'otherFascists': otherFascists,
        'hitlerId': hitlerId,
      };
}

class Game {
  final String id;
  final int minPlayers = 5;
  final int maxPlayers = 10;
  bool isStarted;
  late GameState gameState;
  Function? startGameCallback;
  Function? updateStateCallback;

  Game({
    required this.id,
    required this.isStarted,
    this.startGameCallback,
    this.updateStateCallback,
  });

  void startGame() {
    startGameCallback!();
    isStarted = true;
  }

  void updateState(GameState gs) {
    updateStateCallback!(gs);
  }

  Map<String, GameState> nightPhase(List<User> users) {
    List<String> userIds = [];
    Map<String, GameState> userStates = {};
    for (User user in users) {
      userIds.add(user.id);
    }
    // shuffle the list of users
    userIds.shuffle();

    print("userIds: $userIds");
    // number of fascists for 7-10 players is num_of_players modulus 3
    int numFascists = 1;
    if (users.length >= 7 && users.length <= 10) {
      numFascists = users.length ~/ 3;
    }

    // assign roles to each user
    List<String> fascistIds = [];
    for (var i = 0; i < users.length; i++) {
      userStates[userIds[i]] = GameState();
      if (i < numFascists) {
        userStates[userIds[i]]!.isFascist = true;
        fascistIds.add(userIds[i]);
      } else if (i == numFascists) {
        userStates[userIds[i]]!.isHitler = true;
        userStates[userIds[i]]!.isFascist = true;
      }
    }

    if (users.length == 5 || users.length == 6) {
      userStates[userIds[fascistIds.length]]!.otherFascists = fascistIds;
    }
    for (var i = 0; i < fascistIds.length; i++) {
      userStates[fascistIds[i]]!.otherFascists = fascistIds;
      userStates[fascistIds[i]]!.hitlerId = userIds[numFascists];
    }

    return userStates;
  }

  void updateGameState(dynamic gameState) {
    this.gameState = gameState;
  }
}
