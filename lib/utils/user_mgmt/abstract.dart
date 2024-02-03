import 'package:peerdart/peerdart.dart';
import "package:night/models/user.dart";

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
