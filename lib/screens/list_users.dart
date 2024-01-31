import 'package:flutter/material.dart';
import 'package:night/models/user.dart';
import 'package:night/utils/lobbyclasses.dart';

class UserListBuilder {
  static String _determineUserId(Object user) {
    if (user is HostUser || user is NormalUser) {
      if (user is User) {
        return user.id;
      }
      return "";
      // raise error
      // throw Exception("User is not of type User");
    }
    return "";
    // raise error
    // throw Exception("User is not of type HostUser or NormalUser");
  }

  static LayoutBuilder buildUserList(List<User> users, Object user) {
    final String myId = _determineUserId(user);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double padding =
            constraints.maxWidth > 800 ? constraints.maxWidth * 0.1 : 0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (BuildContext context, int index) {
              final User user = users[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.8,
                color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                child: ListTile(
                  leading: user.isHost ? const Icon(Icons.king_bed) : null,
                  title: Text(
                    user.name + (user.id == myId ? ' (You)' : ''),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
