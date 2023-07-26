class User {
  final String id;
  final String name;
  final String lastSeen;
  final bool isHost;

  User(this.id, this.name, this.lastSeen, this.isHost);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastSeen': lastSeen,
        'isHost': isHost,
      };

  static User fromJson(Map<String, dynamic> json) => User(
        json['id'],
        json['name'],
        json['lastSeen'],
        json['isHost'],
      );
}
