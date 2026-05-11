class AuthResponse {
  final String token;
  final String userId;

  const AuthResponse({required this.token, required this.userId});

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      AuthResponse(token: json['token'] as String, userId: json['user_id'] as String);
}
