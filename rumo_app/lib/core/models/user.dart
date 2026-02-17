/// Usuário autenticado (Fase 1: local; depois Firebase/Google/Microsoft).
class AppUser {
  final String id;
  final String email;
  final String name;
  final String profile;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.profile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profile: json['profile'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'profile': profile,
      };

  bool get isGestorCentral => profile == 'gestor_central';
  bool get isGestorUnidade => profile == 'gestor_unidade';
  bool get isUsuario => profile == 'usuario';
}
