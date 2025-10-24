class User {
  final String username;
  final bool isAdmin;

  User({required this.username, this.isAdmin = false});

  Map<String, dynamic> toJson() => {
    'username': username,
    'isAdmin': isAdmin,
  };

  factory User.fromJson(Map<String, dynamic> j) => User(
    username: j['username'] as String,
    isAdmin: j['isAdmin'] as bool? ?? false,
  );
}
