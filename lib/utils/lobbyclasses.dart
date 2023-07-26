import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:mob/models/user.dart";
import "package:mob/utils/lobby.dart";

class HostUser {
  late Peer peer; // Peer instance representing the host
  late List<User> connectedUsers; // List of connected users
  String gameCode;
  StreamController<List<User>> controller;
  List<StreamSubscription> subscriptions = [];
  late List<DataConnection> connections; // List of peer connections

  HostUser(String name, this.gameCode, this.controller) {
    var hostId = "mob182388inu-$gameCode";
    peer = Peer(id: hostId);
    connectedUsers = [User(hostId, name, DateTime.now().toString(), true)];
    connections = [];

    // every 5 seconds, send the lobby list to all connected users
    Timer.periodic(const Duration(seconds: 5), (timer) {
      // check each user's last seen time, remove them if they are inactive for 10 seconds
      var now = DateTime.now();
      connectedUsers.removeWhere((user) {
        var lastSeen = DateTime.parse(user.lastSeen);
        if (user.isHost) return false; // Don't remove the host
        return now.difference(lastSeen).inSeconds > 5;
      });
      controller.add(List.from(connectedUsers));
      sendLobbyList();
    });

    subscriptions.add(peer.on('open').listen((_) {
      print('Open: We are the host');
      controller.add(List.from(connectedUsers));
    }));

    subscriptions.add(peer.on<DataConnection>('connection').listen((peerConn) {
      print('Connection: Connect received: ${peerConn.peer}');
      connections.add(peerConn);
      peerConn.on('data').listen((data) {
        var rawData = jsonDecode(data);
        var user = User.fromJson(rawData['data']);
        // check if the last seen time is more than 5 seconds ago
        // and remove the user if it is in the list.
        var now = DateTime.now();
        var index = connectedUsers.indexWhere((u) => u.name == user.name);

        if (index >= 0) {
          connectedUsers[index] = user;
        } else {
          connectedUsers.add(user);
        }
        connectedUsers.removeWhere((user) {
          var lastSeen = DateTime.parse(user.lastSeen);
          if (user.isHost) return false; // Don't remove the host
          return now.difference(lastSeen).inSeconds > 5;
        });
        controller.add(List.from(connectedUsers));
        controller.add(List.from(connectedUsers));
        sendLobbyList();
      });
    }));

    subscriptions.add(peer.on<DataConnection>('disconnection').listen((data) {
      connectedUsers.remove(User(data.peer, '', '', false));
      controller.add(List.from(connectedUsers));
      connections.removeWhere((conn) => conn.peer == data.peer);
    }));
  }

  // Method to send lobby list
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
      // arst
    }
  }
}

class NormalUser {
  late Peer? peer; // Peer instance representing the normal user
  late String gameCode, name, hostId;
  late List<User> connectedUsers;
  StreamController<List<User>> controller;
  List<StreamSubscription> subscriptions = [];
  late Function hostDisconnectedCallback;
  bool isAdding = false;

  DataConnection? hostConn;

  NormalUser(this.name, this.gameCode, this.controller,
      this.hostDisconnectedCallback) {
    hostId = "mob182388inu-$gameCode";
    var peerId = "$hostId-${generateRandomCode(5)}";
    peer = Peer(id: peerId);
    connectedUsers = [];

    subscriptions.add(peer!.on('open').listen((_) {
      print('Open: We are not the host');
      hostConn = peer?.connect(hostId);
      hostConn?.on('open').listen((_) {
        print('Open: Host connection established');

        sendUserJoinEvent();
        // now send keep alive messages every 5 seconds
        Timer.periodic(const Duration(seconds: 5), (timer) {
          if (hostConn?.open == false) {
            timer.cancel();
            return;
          }
          sendUserJoinEvent();
        });
      });

      // if the host does not respond within 10 seconds, disconnect
      Timer(Duration(seconds: 1), () {
        if (hostConn?.open == false) {
          print('Close: Host did not respond');
          hostDisconnectedCallback(); // Call the callback function
        }
      });

      hostConn?.on('close').listen((_) {
        print('Close: Host has left the game');
        hostDisconnectedCallback(); // Call the callback function
      });

      hostConn?.on('data').listen((data) {
        var payload = jsonDecode(data);
        if (payload['event'] == 'lobby-list') {
          var users = List<User>.from(
              payload['data']['users'].map((user) => User.fromJson(user)));
          connectedUsers.clear();
          connectedUsers.addAll(users);
          isAdding = true;
          controller.add(List.from(connectedUsers));
          isAdding = false;
        }
      });
    }));
  }

  // Method to send user join event, optional parameter for timestamp
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
    print("sending message to host $payload");
    hostConn?.send(jsonEncode(payload));
  }

  void dispose() {
    // timestamp from 10 seconds ago to indicate that the user has left
    print("disposinig");
    var timestamp =
        DateTime.now().subtract(const Duration(seconds: 30)).toString();
    sendUserJoinEvent(timestamp);
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    if (!isAdding) {
      peer?.dispose();
    }
  }
}
