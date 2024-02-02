import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/utils/lobby.dart";

import '../models/game.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('UserManagement');

void addTestUsers(List<User> users, StreamController<List<User>> controller) {
  var timeForUsers = DateTime.now().toString();

  users.add(User('1', 'Francis', timeForUsers, false));
  users.add(User('2', 'Theodore', timeForUsers, false));
  users.add(User('3', 'Michaelangelo', timeForUsers, false));
  users.add(User('4', 'Rocky', timeForUsers, false));
  users.add(User('5', 'Devin', timeForUsers, false));
  users.add(User('6', 'Tamantha', timeForUsers, false));
  users.add(User('7', 'Britney', timeForUsers, false));

  Timer(const Duration(seconds: 0), () {
    _logger.info("Adding host user to the controller");
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

  HostUser(String name, this.gameCode, this.controller, this.game) {
    initializeHostUser(name);
  }

  void initializeHostUser(String name) {
    hostId = "night182388inu-$gameCode";
    peer = Peer(id: hostId);
    var user = User(hostId, name, DateTime.now().toString(), true);
    userConnections[hostId] = UserConnection(user, null);

    setUpEventListeners();
    setUpPeriodicTasks();

    // Send the lobby list to the connected users
    if (gameCode == "ARST") {
      addTestUsers(
          userConnections.values.map((uc) => uc.user).toList(), controller);
    }
  }

  void setUpEventListeners() {
    subscriptions.add(peer.on('open').listen((conn_id) {
      _logger.info('Open: We are the host');
      // var users = userConnections.values.map((uc) => uc.user).toList();
      // controller.add(users);
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
        // var rawData = jsonDecode(data);
        // var userData = User.fromJson(rawData['data']);
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
    void task(timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      var users = userConnections.values.map((uc) => uc.user).toList();
      controller.add(users);
      if (users.length > 1) {
        sendLobbyList();
      }
    }

    Timer.periodic(const Duration(seconds: 5), (timer) {
      task(timer);
    });
  }

  // void removeInactiveUsers() {
  //   var now = DateTime.now();
  //   connectedUsers.removeWhere((user) {
  //     var lastSeen = DateTime.parse(user.lastSeen);
  //     if (user.isHost) return false;
  //     var isInactive = now.difference(lastSeen).inSeconds > 5;
  //     if (isInactive && game.isStarted) {
  //       game.endGame();
  //     }
  //     return isInactive;
  //   });

  //   if (!controller.isClosed) {
  //     controller.add(List.from(connectedUsers));
  //   }
  // }

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
    Map<String, GameState> userStates =
        game.nightPhase(List.from(userConnections.keys));
    userStates.forEach((key, value) {
      // _logger.info("$key : ${value.toJson()}");
      if (hostId == key) {
        game.updateGameState(value);
        return;
      }
      var payload = {
        "event": "game-state",
        "data": value.toJson(),
      };
      // TODO: check if connection is defined and open
      // if (connectionMap[key] == null || connectionMap[key]!.open == false) {
      // return;
      // }
      // connectionMap[key]!.send(jsonEncode(payload));
    });

    game.startGame();
    sendLobbyList();
  }

  void broadcastEvent(Map<String, dynamic> event) {
    var encodedEvent = jsonEncode(event);
    for (var connection in List.from(userConnections.values)) {
      if (connection.open == false) continue;
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
  }
}

class NormalUser implements AbstractUser {
  late Peer? peer;
  late String gameCode, name, hostId, id;
  late List<User> connectedUsers = [];
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
    // do nothing
  }

  void initializeNormalUser() {
    hostId = "night182388inu-$gameCode";
    var peerId = "$hostId-${generateRandomCode(5)}";
    peer = Peer(id: peerId);
    id = peerId;
    setUpEventListeners();
    setUpConnectionCheck();
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
        // attemptReconnect();
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
          var users = List<User>.from(
              payload['data']['users'].map((user) => User.fromJson(user)));
          connectedUsers.clear();
          connectedUsers.addAll(users);
          if (!controller.isClosed) {
            controller.add(List.from(connectedUsers));
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

  void setUpConnectionCheck() {
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
