import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/models/game.dart";
import 'package:logging/logging.dart';
import "package:night/utils/user_mgmt/abstract.dart";

final Logger _logger = Logger('HostManagement');

void addTestUsers(List<User> users, StreamController<List<User>> controller,
    [Map<String, UserConnection>? userConnections]) {
  var timeForUsers = DateTime.now().toString();

  conditionalAdd(name, id) {
    if (users.where((user) => user.id == id).isEmpty) {
      users.add(User(id, name, timeForUsers, false));
    }
  }

  conditionalAdd('Francis', '1');
  conditionalAdd('Theodore', '2');
  conditionalAdd('Michaelangelo', '3');
  conditionalAdd('Rocky', '4');
  conditionalAdd('Devin', '5');
  conditionalAdd('Tamantha', '6');
  conditionalAdd('Britney', '7');

  if (userConnections != null) {
    for (var user in users) {
      userConnections[user.id] = UserConnection(user, null);
    }
  }

  Timer(const Duration(seconds: 0), () {
    controller.add(users);
  });
}

class HostUser implements AbstractUser {
  late Peer peer;
  final String gameCode;
  late Game game;
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late String hostId, id;
  late Map<String, UserConnection> userConnections = {};
  late List<Timer> timers = [];

  HostUser(String name, this.gameCode, this.controller, this.game) {
    initializeHostUser(name);
  }

  void initializeHostUser(String name) {
    hostId = "night182388inu-$gameCode";
    peer = Peer(id: hostId);
    var user = User(hostId, name, DateTime.now().toString(), true);
    userConnections[hostId] = UserConnection(user, null);
    _logger.info("Starting host user with id: $hostId");

    setUpEventListeners();
    setUpPeriodicTasks();

    // Send the lobby list to the connected users
    if (gameCode == "ARST") {
      addTestUsers(userConnections.values.map((uc) => uc.user).toList(),
          controller, userConnections);
      timers.add(Timer.periodic(const Duration(seconds: 5), (timer) {
        addTestUsers(userConnections.values.map((uc) => uc.user).toList(),
            controller, userConnections);
      }));
    } else {
      Timer(const Duration(seconds: 0), () {
        // _logger.info("Adding host user to the controller");
        controller.add(userConnections.values.map((uc) => uc.user).toList());
      });
    }
  }

  void setUpEventListeners() {
    subscriptions.add(peer.on<DataConnection>('connection').listen((peerConn) {
      _logger.info('Connecting... ${peerConn.peer}');
      peerConn.on('open').listen((_) {
        _logger.info('Connection established: ${peerConn.peer}');
        if (game.isStarted) {
          return;
        }
        var user = User(peerConn.peer, "", DateTime.now().toString(), false);
        userConnections[peerConn.peer] = UserConnection(user, peerConn);
      });

      peerConn.on('close').listen((_) {
        _logger.info('Close: Connection closed: ${peerConn.peer}');
        userConnections.remove(peerConn.peer);
      });

      peerConn.on('data').listen((data) {
        var user = userConnections[peerConn.peer];
        if (user != null) {
          user.lastSeen = DateTime.now().toString();
        }
      });
    }));

    subscriptions.add(peer.on<DataConnection>('disconnection').listen((data) {
      _logger.info('Disconnect received: ${data.peer}');
      userConnections.remove(data.peer);
    }));
  }

  void setUpPeriodicTasks() {
    void removeInactiveUsers() {
      var now = DateTime.now();
      userConnections.removeWhere((key, value) =>
          now.difference(DateTime.parse(value.lastSeen)).inSeconds > 30);
    }

    void task(timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      if (userConnections.length > 1) {
        removeInactiveUsers();
        sendLobbyList();
      }
    }

    Timer.periodic(const Duration(seconds: 5), (timer) {
      task(timer);
    });
  }

  void sendLobbyList() {
    var payload = {
      "event": "lobby-list",
      "data": {
        "users": userConnections
            .map((key, value) => MapEntry(key, value.user.toJson()))
      },
    };
    broadcastEvent(payload);
  }

  void endGame() {
    game.endGame();
    var payload = {
      "event": "end-game",
      "data": "Game has ended",
    };
    broadcastEvent(payload);
    sendLobbyList();
  }

  @override
  void startGame() {
    if (userConnections.length < game.minPlayers) {
      _logger.info("Not enough players to start the game");
      return;
    }
    Map<String, GameState> userStates =
        game.nightPhase(userConnections.values.map((uc) => uc.user).toList());

    // We don't broadcast the game state to everyone
    // We only send the game state for a user to that user
    userStates.forEach((key, value) {
      if (hostId == key) {
        game.updateGameState(value);
        return;
      }
      var payload = {
        "event": "game-state",
        "data": value.toJson(),
      };

      if (userConnections[key] == null ||
          userConnections[key]!.connection == null) {
        return;
      }

      userConnections[key]!.connection!.send(jsonEncode(payload));
    });

    game.startGame();
  }

  void broadcastEvent(Map<String, dynamic> event) {
    var encodedEvent = jsonEncode(event);
    for (var connection in userConnections.values.map((uc) => uc.connection)) {
      if (connection == null) continue;
      connection.send(encodedEvent);
    }
  }

  void dispose() {
    if (game.isStarted) {
      endGame();
    }
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    peer.dispose();
    for (var connection
        in userConnections.values.map((uc) => uc.connection).toList()) {
      if (connection == null) continue;
      connection.close();
    }
    if (!controller.isClosed) {
      controller.close();
    }
    for (var timer in timers) {
      timer.cancel();
    }
  }
}
