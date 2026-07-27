class Device {
  final String id;
  final String name;
  final String ip;
  final int port;
  final bool connected;

  const Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.connected = false,
  });

  Device copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    bool? connected,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      connected: connected ?? this.connected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'connected': connected,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      connected: json['connected'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'Device(id: $id, name: $name, ip: $ip, port: $port, connected: $connected)';
  }
}
