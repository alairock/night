import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/utils/lobby.dart";

class HostUser {
  late Peer peer;
  late List<User> connectedUsers = [];
  final String gameCode;
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late List<DataConnection> connections = [];
  bool isAdding = false;

  HostUser(String name, this.gameCode, this.controller) {
    initializeHostUser(name);
  }

  void initializeHostUser(String name) {
    var hostId = "night182388inu-$gameCode";
    peer = Peer(id: hostId);
    connectedUsers.add(User(hostId, name, DateTime.now().toString(), true));
    setUpEventListeners();
    setUpPeriodicTasks();
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
      connectedUsers.remove(User(data.peer, '', '', false));
      isAdding = true;
      controller.add(List.from(connectedUsers));
      isAdding = false;
      connections.removeWhere((conn) => conn.peer == data.peer);
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
      return now.difference(lastSeen).inSeconds > 5;
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

  void startGame() {
    var payload = {
      "event": "start-game",
      "data": {"users": connectedUsers.map((u) => u.toJson()).toList()}
    };
    broadcastEvent(payload);
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
  late String gameCode, name, hostId;
  late List<User> connectedUsers = [];
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late Function hostDisconnectedCallback;
  bool isAdding = false;

  DataConnection? hostConn;

  NormalUser(this.name, this.gameCode, this.controller,
      this.hostDisconnectedCallback) {
    initializeNormalUser();
  }

  void initializeNormalUser() {
    hostId = "night182388inu-$gameCode";
    var peerId = "$hostId-${generateRandomCode(5)}";
    peer = Peer(id: peerId);
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
      });
    }));
  }

  void setUpConnectionCheck() {
    Timer(Duration(seconds: 1), () {
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
