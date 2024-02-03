import 'dart:async';
import 'dart:convert';
import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";
import "package:night/models/game.dart";
import "package:night/utils/random_code.dart";
import "package:night/utils/user_mgmt/abstract.dart";
import 'package:logging/logging.dart';

final Logger _logger = Logger('UserManagement');

class NormalUser implements AbstractUser {
  late Peer? peer;
  late String gameCode, name, hostId, id;
  final StreamController<List<User>> controller;
  final List<StreamSubscription> subscriptions = [];
  late Function hostDisconnectedCallback;
  late Game game;
  Timer? connectionCheckTimer;
  DataConnection? hostConn;
  late List<Timer> timers = [];

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
  }

  void setUpEventListeners() {
    subscriptions.add(peer!.on('open').listen((_) {
      _logger.info('Open: We are not the host');

      hostConn = peer?.connect(hostId);
      hostConn?.on('open').listen((_) {
        _logger.info('Open: Host connection established');

        sendUserJoinEvent();
        timers.add(Timer.periodic(const Duration(seconds: 5), (timer) {
          if (hostConn?.open == false) {
            timer.cancel();
            return;
          }
          sendUserJoinEvent();
        }));
      });

      hostConn?.on('close').listen((_) {
        _logger.info('Close: Host has left the game');
        hostDisconnectedCallback(); // Pop open a modal to inform the user
      });

      hostConn?.on('error').listen((error) {
        _logger.info('Connection error: $error');
        // attemptReconnect();
        hostDisconnectedCallback(); // Pop open a modal to inform the user
      });

      hostConn?.on('data').listen((data) {
        var payload = jsonDecode(data);
        if (payload['event'] == 'lobby-list') {
          _logger.info('Lobby list received');
          List<User> users = List.from(payload['data']['users']
              .values
              .map((user) => User.fromJson(user)));

          if (!controller.isClosed) {
            controller.add(users);
          }
        }
        if (payload['event'] == 'end-game') {
          game.endGame();
        }
        if (payload['event'] == 'game-state') {
          GameState gs = GameState.fromJson(payload['data']);
          game.updateGameState(gs);
        }
      });
    }));
  }

  void sendUserJoinEvent([String? timestamp]) {
    _logger.info('Sending user keepalive event');
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

  void dispose() async {
    var timestamp =
        DateTime.now().subtract(const Duration(seconds: 30)).toString();
    sendUserJoinEvent(
        timestamp); // in the past, so the host knows we're gone/done

    for (var subscription in subscriptions) {
      subscription.cancel();
    }
    hostConn?.close();
    peer?.dispose();
    if (!controller.isClosed) {
      await controller.sink.close();
      controller.close();
    }
    for (var timer in timers) {
      timer.cancel();
    }
  }
}
