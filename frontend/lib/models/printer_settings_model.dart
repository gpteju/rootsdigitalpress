// CHANGE-2026-09-07: Created Printer Settings Model.

class PrinterSettingsModel {
  final int? id;
  final bool printerEnabled;
  final String printerIp;
  final int printerPort;
  final String? updatedAt;

  PrinterSettingsModel({
    this.id,
    required this.printerEnabled,
    required this.printerIp,
    required this.printerPort,
    this.updatedAt,
  });

  factory PrinterSettingsModel.fromJson(Map<String, dynamic> json) {
    return PrinterSettingsModel(
      id: json['id'],
      printerEnabled: json['printer_enabled'] == 1 || json['printer_enabled'] == true,
      printerIp: json['printer_ip'] ?? '',
      printerPort: json['printer_port'] ?? 9100,
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'printer_enabled': printerEnabled ? 1 : 0,
      'printer_ip': printerIp,
      'printer_port': printerPort,
    };
  }
}
