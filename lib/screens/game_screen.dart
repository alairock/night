import 'package:flutter/material.dart';
import 'package:night/models/game.dart';
import 'package:night/models/user.dart';
import 'package:night/utils/user_management.dart';

// Define a type alias for better readability
typedef GameScreenBuilder = Function(GameState gameState, List<User> users,
    Object user, bool showRole, Function updateShowRole);

GameScreenBuilder buildGameScreen({
  required AbstractUser hostUser,
}) {
  return (GameState gameState, List<User> users, Object user, bool showRole,
      Function updateShowRole) {
    Map<String, String> userIdToName = {};
    for (var user in users) {
      userIdToName[user.id] = user.name;
    }

    String myId = "";
    if (user is HostUser) {
      myId = user.hostId;
    } else if (user is NormalUser) {
      myId = user.id;
    } else {
      return Container();
    }

    return Scrollbar(
        child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Center(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showRole)
                  GestureDetector(
                      onTap: () {
                        updateShowRole();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Image.asset(
                          gameState.isHitler
                              ? "assets/hitler.jpg"
                              : gameState.isFascist
                                  ? "assets/fascist.jpg"
                                  : "assets/liberal.jpg",
                          width: 150,
                        ),
                      ))
                else
                  GestureDetector(
                      onTap: () {
                        updateShowRole();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Image.asset(
                          "assets/secret.jpg",
                          width: 150,
                        ),
                      )),
                if (gameState.isFascist &&
                    gameState.otherFascists.isNotEmpty &&
                    showRole)
                  // bold text
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text("Fellow Fascists:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                if (gameState.isFascist && showRole)
                  for (var fa in gameState.otherFascists)
                    if (fa != myId)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            "• ${userIdToName[fa]} ${fa == myId ? '(You)' : ''}",
                          )),
                const Text(""),
                if (gameState.hitlerId != "" &&
                    gameState.hitlerId != myId &&
                    showRole)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text("Hitler:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                if (gameState.hitlerId != "" &&
                    gameState.hitlerId != myId &&
                    showRole)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        "• Hitler: ${userIdToName[gameState.hitlerId]}",
                      )),
                if (!showRole) const Text(""),
                // bold text
                if (!showRole)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text("Sit in this order:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                if (!showRole)
                  for (var u in users)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          "• ${userIdToName[u.id]} ${u.id == myId ? '(You)' : ''}",
                        )),
                if (user is HostUser)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0XFFde6e46),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: user.endGame,
                      child: const Text('End Game'),
                    ),
                  ),
              ],
            ))));
  };
}
