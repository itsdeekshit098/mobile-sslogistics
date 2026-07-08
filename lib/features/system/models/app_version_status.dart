class AppVersionConfig {
  final int? minAndroidVersionCode;
  final String? message;

  const AppVersionConfig({this.minAndroidVersionCode, this.message});

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    return AppVersionConfig(
      minAndroidVersionCode: json['minAndroidVersionCode'] as int?,
      message: json['forceUpdateMessage'] as String?,
    );
  }
}
