import 'package:night/models/user.dart';

class GameState {
  late bool isHitler = false;
  late bool isFascist = false;
  late List otherFascists = [];
  late String hitlerId = "";

  GameState(
    this.isHitler,
    this.isFascist,
    this.otherFascists,
    this.hitlerId,
  );

  Map<String, dynamic> toJson() => {
        'isHitler': isHitler,
        'isFascist': isFascist,
        'otherFascists': otherFascists,
        'hitlerId': hitlerId,
      };

  static GameState fromJson(Map<String, dynamic> json) => GameState(
        json['isHitler'],
        json['isFascist'],
        json['otherFascists'],
        json['hitlerId'],
      );
}

class Game {
  final String id;
  final int minPlayers = 5;
  final int maxPlayers = 10;
  bool isStarted;
  late GameState gameState;
  Function? startGameCallback;
  Function? endGameCallback;
  Function? updateStateCallback;

  Game({
    required this.id,
    required this.isStarted,
    this.startGameCallback,
    this.endGameCallback,
    this.updateStateCallback,
  });

  void startGame() {
    startGameCallback!();
    isStarted = true;
  }

  void endGame() {
    endGameCallback!();
    isStarted = false;
  }

  void updateGameState(GameState gameState) {
    updateStateCallback!(gameState);
    this.gameState = gameState;
  }

  Map<String, GameState> nightPhase(List<User> users) {
    List<String> userIds = [];
    Map<String, GameState> userStates = {};
    for (User user in users) {
      userIds.add(user.id);
    }
    // shuffle the list of users
    userIds.shuffle();

    // number of fascists for 7-10 players is num_of_players modulus 3
    int numFascists = 1;
    if (users.length >= 7 && users.length <= 10) {
      numFascists = users.length ~/ 3;
    }

    // assign roles to each user
    List<String> fascistIds = [];
    for (var i = 0; i < users.length; i++) {
      userStates[userIds[i]] = GameState(false, false, [], "");
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
}
