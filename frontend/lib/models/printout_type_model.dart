// CHANGE-2026-09-07: Created Printout Type data model.

class PrintoutTypeModel {
  final int? id;
  final String name;
  final String sides; // Single / Double
  final String colorMode; // Color / B/W
  final String? description;
  final bool isActive;

  PrintoutTypeModel({
    this.id,
    required this.name,
    this.sides = 'Single',
    this.colorMode = 'B/W',
    this.description,
    this.isActive = true,
  });

  factory PrintoutTypeModel.fromJson(Map<String, dynamic> json) {
    return PrintoutTypeModel(
      id: json['id'],
      name: json['name'] ?? '',
      sides: json['sides'] ?? 'Single',
      colorMode: json['color_mode'] ?? 'B/W',
      description: json['description'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'sides': sides,
    'color_mode': colorMode,
    'description': description,
    'is_active': isActive ? 1 : 0,
  };
}
