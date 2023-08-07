import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/utils/lobby.dart";

import '../models/game.dart';

void addTestUsers(List<User> users, StreamController<List<User>> controller) {
  var timeForUsers = DateTime.now().toString();
  var testUsers = [
    User('1', 'User 1', timeForUsers, false),
    User('2', 'User 2', timeForUsers, false),
    User('3', 'User 3', timeForUsers, false),
    User('4', 'User 4', timeForUsers, false),
    User('5', 'User 5', timeForUsers, false),
    User('6', 'User 6', timeForUsers, false),
    User('7', 'User 7', timeForUsers, false),
  ];

  var now = DateTime.now().toString();
  for (var testUser in testUsers) {
    var index = users.indexWhere((u) => u.name == testUser.name);
    if (index >= 0) {
      users[index].lastSeen = now;
    } else {
      users.add(testUser);
    }
  }
  if (!controller.isClosed) {
    controller.add(List.from(users));
  }
}

class HostUser {
  late Peer peer;
  late List<User> connectedUsers = [];
  final String gameCode;
  late Game game;
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late List<DataConnection> connections = [];
  late Map<String, DataConnection> connectionMap = {};
  late String hostId, id;
  bool isAdding = false;

  HostUser(String name, this.gameCode, this.controller, this.game) {
    initializeHostUser(name);
  }

  void initializeHostUser(String name) {
    hostId = "night182388inu-$gameCode";
    peer = Peer(id: hostId);
    id = hostId;
    connectedUsers.add(User(hostId, name, DateTime.now().toString(), true));
    setUpEventListeners();
    setUpPeriodicTasks();

    // Send the lobby list to the connected users
    addTestUsers(connectedUsers, controller);
    Timer.periodic(const Duration(seconds: 5), (timer) {
      addTestUsers(connectedUsers, controller);
    });
  }

  void setUpEventListeners() {
    subscriptions.add(peer.on('open').listen((_) {
      print('Open: We are the host');
      isAdding = true;
      controller.add(List.from(connectedUsers));
      isAdding = false;
    }));

    subscriptions.add(peer.on<DataConnection>('connection').listen((peerConn) {
      print('Connection: Connect received: ${peerConn.peer}');
      connections.add(peerConn);
      peerConn.on('data').listen((data) {
        var rawData = jsonDecode(data);
        var user = User.fromJson(rawData['data']);
        var index = connectedUsers.indexWhere((u) => u.name == user.name);
        connectionMap[user.id] = peerConn;
        if (index >= 0) {
          connectedUsers[index] = user;
        } else {
          connectedUsers.add(user);
        }
        removeInactiveUsers();
        isAdding = true;
        controller.add(List.from(connectedUsers));
        isAdding = false;
        sendLobbyList();
      });
    }));

    subscriptions.add(peer.on<DataConnection>('disconnection').listen((data) {
      print('Disconnection: Disconnect received: ${data.peer}');
      connectedUsers.remove(User(data.peer, '', '', false));
      isAdding = true;
      controller.add(List.from(connectedUsers));
      isAdding = false;
      connections.removeWhere((conn) => conn.peer == data.peer);
      if (game.isStarted) {
        game.endGame();
      }
    }));
  }

  void setUpPeriodicTasks() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      removeInactiveUsers();
      controller.add(List.from(connectedUsers));
      sendLobbyList();
    });
  }

  void removeInactiveUsers() {
    var now = DateTime.now();
    connectedUsers.removeWhere((user) {
      var lastSeen = DateTime.parse(user.lastSeen);
      if (user.isHost) return false;
      var isInactive = now.difference(lastSeen).inSeconds > 5;
      if (isInactive && game.isStarted) {
        game.endGame();
      }
      return isInactive;
    });

    if (!controller.isClosed) {
      isAdding = true;
      controller.add(List.from(connectedUsers));
      isAdding = false;
    }
  }

  void sendLobbyList() {
    var payload = {
      "event": "lobby-list",
      "data": {"users": connectedUsers.map((u) => u.toJson()).toList()}
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

  void startGame() {
    Map<String, GameState> userStates = game.nightPhase(connectedUsers);
    userStates.forEach((key, value) {
      // print("$key : ${value.toJson()}");
      if (hostId == key) {
        game.updateGameState(value);
        return;
      }
      var payload = {
        "event": "game-state",
        "data": value.toJson(),
      };
      // check if connection is defined and open
      if (connectionMap[key] == null || connectionMap[key]!.open == false) {
        return;
      }
      connectionMap[key]!.send(jsonEncode(payload));
    });

    game.startGame();
    sendLobbyList();
  }

  void broadcastEvent(Map<String, dynamic> event) {
    var encodedEvent = jsonEncode(event);
    for (var connection in connections) {
      if (connection.open == false) continue;
      connection.send(encodedEvent);
    }
  }

  void dispose() {
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    peer.dispose();
    for (var connection in connections) {
      connection.close();
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

class NormalUser {
  late Peer? peer;
  late String gameCode, name, hostId, id;
  late List<User> connectedUsers = [];
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late Function hostDisconnectedCallback;
  late Game game;
  bool isAdding = false;

  DataConnection? hostConn;

  NormalUser(this.name, this.gameCode, this.controller,
      this.hostDisconnectedCallback, this.game) {
    initializeNormalUser();
  }

  void initializeNormalUser() {
    hostId = "night182388inu-$gameCode";
    var peerId = "$hostId-${generateRandomCode(5)}";
    peer = Peer(id: peerId);
    id = peerId;
    setUpEventListeners();
    setUpConnectionCheck();
  }

  void setUpEventListeners() {
    subscriptions.add(peer!.on('open').listen((_) {
      print('Open: We are not the host');
      hostConn = peer?.connect(hostId);
      hostConn?.on('open').listen((_) {
        print('Open: Host connection established');

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
        print('Close: Host has left the game');
        hostDisconnectedCallback();
      });

      hostConn?.on('data').listen((data) {
        var payload = jsonDecode(data);
        if (payload['event'] == 'lobby-list') {
          var users = List<User>.from(
              payload['data']['users'].map((user) => User.fromJson(user)));
          connectedUsers.clear();
          connectedUsers.addAll(users);
          isAdding = true;
          if (!controller.isClosed) {
            controller.add(List.from(connectedUsers));
          }
          isAdding = false;
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
    Timer(const Duration(seconds: 1), () {
      if (hostConn?.open == false) {
        print('Close: Host did not respond');
        hostDisconnectedCallback();
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
    if (!controller.isClosed) {
      controller.close();
    }
  }
}
