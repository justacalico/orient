/// A saved qBittorrent WebUI connection.
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.username = '',
    this.password = '',
    this.rememberSession = true,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final bool rememberSession;

  /// Host label shown in lists, without credentials.
  String get displayHost {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl;
    return uri.port == 80 || uri.port == 443
        ? uri.host
        : '${uri.host}:${uri.port}';
  }

  /// Normalizes user input into a usable base URL. Accepts bare hosts,
  /// host:port pairs and full URLs with or without a path prefix.
  static String normalizeBaseUrl(String raw) {
    var input = raw.trim();
    if (input.isEmpty) return input;
    if (!input.contains('://')) input = 'http://$input';
    final uri = Uri.parse(input);
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();
  }

  ServerProfile copyWith({
    String? name,
    String? baseUrl,
    String? username,
    String? password,
    bool? rememberSession,
  }) {
    return ServerProfile(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      rememberSession: rememberSession ?? this.rememberSession,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
        'rememberSession': rememberSession,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        rememberSession: json['rememberSession'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.username == username &&
      other.password == password &&
      other.rememberSession == rememberSession;

  @override
  int get hashCode =>
      Object.hash(id, name, baseUrl, username, password, rememberSession);
}
