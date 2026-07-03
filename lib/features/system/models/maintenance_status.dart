class MaintenanceStatus {
  final bool maintenanceMode;
  final String? message;

  const MaintenanceStatus({required this.maintenanceMode, this.message});

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    return MaintenanceStatus(
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}
