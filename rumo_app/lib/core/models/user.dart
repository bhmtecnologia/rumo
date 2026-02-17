/// Usuário autenticado (Fase 1: local; depois Firebase/Google/Microsoft).
class AppUser {
  final String id;
  final String email;
  final String name;
  final String profile;
  final List<String> costCenterIds;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.profile,
    this.costCenterIds = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final ids = json['costCenterIds'];
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profile: json['profile'] as String,
      costCenterIds: ids is List ? ids.map((e) => e.toString()).toList() : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'profile': profile,
        'costCenterIds': costCenterIds,
      };

  bool get isGestorCentral => profile == 'gestor_central';
  bool get isGestorUnidade => profile == 'gestor_unidade';
  bool get isUsuario => profile == 'usuario';
  bool get isMotorista => profile == 'motorista';
}
