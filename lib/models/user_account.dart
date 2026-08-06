class UserAccount {
  const UserAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.bio = '',
  });
  final String name;
  final String username;
  final String email;
  final String passwordHash;
  final String bio;

  UserAccount copyWith({
    String? name,
    String? username,
    String? email,
    String? passwordHash,
    String? bio,
  }) => UserAccount(
    name: name ?? this.name,
    username: username ?? this.username,
    email: email ?? this.email,
    passwordHash: passwordHash ?? this.passwordHash,
    bio: bio ?? this.bio,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'email': email,
    'passwordHash': passwordHash,
    'bio': bio,
  };
  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
    bio: json['bio'] as String? ?? '',
  );
}
