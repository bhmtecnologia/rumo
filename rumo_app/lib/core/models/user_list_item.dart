/// Usuário para listagem/edição no backoffice (com costCenterIds).
class UserListItem {
  final String id;
  final String email;
  final String name;
  final String profile;
  final List<String> costCenterIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserListItem({
    required this.id,
    required this.email,
    required this.name,
    required this.profile,
    this.costCenterIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory UserListItem.fromJson(Map<String, dynamic> json) {
    final ids = json['costCenterIds'];
    return UserListItem(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profile: json['profile'] as String,
      costCenterIds: ids is List ? ids.map((e) => e.toString()).toList() : [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'profile': profile,
        'costCenterIds': costCenterIds,
      };

  String get profileLabel {
    switch (profile) {
      case 'gestor_central':
        return 'Gestor Central';
      case 'gestor_unidade':
        return 'Gestor Unidade';
      case 'usuario':
        return 'Usuário';
      default:
        return profile;
    }
  }
}
