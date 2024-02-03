import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/models/game.dart";
import "package:night/utils/random_code.dart";
import 'package:logging/logging.dart';

final Logger _logger = Logger('UserManagement');

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

abstract class AbstractUser {
  // Define the common properties and methods here
  void startGame();
}

class UserConnection {
  User user;
  DataConnection? connection;
  String lastSeen = DateTime.now().toString();

  UserConnection(this.user, this.connection);
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
    subscriptions.add(peer.on('open').listen((conn_id) {
      _logger.info('Open: We are the host');
    }));

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

class NormalUser implements AbstractUser {
  late Peer? peer;
  late String gameCode, name, hostId, id;
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late Function hostDisconnectedCallback;
  late Game game;
  Timer? connectionCheckTimer;
  DataConnection? hostConn;

  NormalUser(this.name, this.gameCode, this.controller,
      this.hostDisconnectedCallback, this.game) {
    initializeNormalUser();
  }

  @override
  void startGame() {
    // do nothing, only the host does this.
  }

  void initializeNormalUser() {
    hostId = "night182388inu-$gameCode";
    var peerId = "$hostId-${generateRandomCode(5)}";
    peer = Peer(id: peerId);
    id = peerId;
    setUpEventListeners();
    setUpPeriodicTasks();
  }

  void setUpEventListeners() {
    subscriptions.add(peer!.on('open').listen((_) {
      _logger.info('Open: We are not the host');
      hostConn = peer?.connect(hostId);
      hostConn?.on('open').listen((_) {
        _logger.info('Open: Host connection established');

        sendUserJoinEvent();
        Timer.periodic(const Duration(seconds: 5), (timer) {
          if (hostConn?.open == false) {
            timer.cancel();
            return;
          }
          sendUserJoinEvent();
        });
      });

      hostConn?.on('close').listen((_) {
        _logger.info('Close: Host has left the game');
        hostDisconnectedCallback();
      });

      hostConn?.on('error').listen((error) {
        _logger.info('Connection error: $error');
        // attemptReconnect();
        hostDisconnectedCallback();
      });

      hostConn?.on('data').listen((data) {
        var payload = jsonDecode(data);
        if (payload['event'] == 'lobby-list') {
          _logger.info('Lobby list received');
          var users = List<User>.from(
              payload['data']['users'].map((user) => User.fromJson(user)));

          if (!controller.isClosed) {
            controller.add(List.from(users));
          }
        }
        if (payload['event'] == 'end-game') {
          game.endGame();
        }
        if (payload['event'] == 'game-state') {
          var gs = GameState.fromJson(payload['data']);
          game.updateGameState(gs);
        }
      });
    }));
  }

  void setUpPeriodicTasks() {
    const int maxRetries = 3; // Number of retries
    const int delayInSeconds = 3; // Delay between each retry in seconds

    int retryCount = 0;

    connectionCheckTimer =
        Timer.periodic(const Duration(seconds: delayInSeconds), (Timer timer) {
      if (hostConn?.open == true) {
        _logger.info('Connection established: Host responded');
        timer.cancel(); // Stop the timer if connection is open
      } else {
        _logger.info('Attempt ${retryCount + 1}: Host did not respond');
        retryCount++;
        if (retryCount >= maxRetries) {
          _logger.info('Close: Host did not respond');
          hostDisconnectedCallback();
          timer.cancel(); // Stop the timer after reaching max retries
        }
      }
    });
  }

  void sendUserJoinEvent([String? timestamp]) {
    var payload = {
      "event": "user-join",
      "timestamp": timestamp ?? DateTime.now().toString(),
      "data": User(peer?.id ?? "", name, timestamp ?? DateTime.now().toString(),
              false)
          .toJson()
    };
    sendHostMessage(payload);
  }

  void sendHostMessage(Map<String, dynamic> payload) {
    if (hostConn?.open == false) return;
    hostConn?.send(jsonEncode(payload));
  }

  void attemptReconnect() {
    int retries = 0;
    const maxRetries = 3;

    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (retries >= maxRetries) {
        _logger.info('Reconnection failed after $maxRetries attempts');
        hostDisconnectedCallback();
        timer.cancel();
        return;
      }
      _logger.info('Reconnection attempt ${retries + 1}');
      hostConn = peer?.connect(hostId);
      if (hostConn?.open == true) {
        _logger.info('Reconnection successful');
        sendUserJoinEvent();
        timer.cancel();
      }
      retries++;
    });
  }

  void dispose() {
    var timestamp =
        DateTime.now().subtract(const Duration(seconds: 30)).toString();
    sendUserJoinEvent(timestamp);
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    hostConn?.close();
    peer?.dispose();
    connectionCheckTimer?.cancel();
    if (!controller.isClosed) {
      controller.close();
    }
  }
}
