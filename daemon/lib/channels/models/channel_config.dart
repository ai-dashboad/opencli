/// Configuration for a message channel
class ChannelConfig {
  /// Whether this channel is enabled
  final bool enabled;

  /// Channel-specific configuration
  final Map<String, dynamic> config;

  /// Allowed user IDs (whitelist)
  final List<String>? allowedUsers;

  /// Rate limit: max messages per minute
  final int? rateLimit;

  ChannelConfig({
    required this.enabled,
    required this.config,
    this.allowedUsers,
    this.rateLimit,
  });

  factory ChannelConfig.fromJson(Map<String, dynamic> json) {
    return ChannelConfig(
      enabled: json['enabled'] as bool? ?? false,
      config: json['config'] as Map<String, dynamic>? ?? {},
      allowedUsers: (json['allowed_users'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      rateLimit: json['rate_limit'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'config': config,
      if (allowedUsers != null) 'allowed_users': allowedUsers,
      if (rateLimit != null) 'rate_limit': rateLimit,
    };
  }
}
