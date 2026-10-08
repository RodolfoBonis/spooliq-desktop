import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';

enum UserType {
  owner('owner', 'Proprietário'),
  admin('admin', 'Administrador'),
  user('user', 'Usuário');

  const UserType(this.value, this.label);

  final String value;
  final String label;

  static UserType fromValue(String? v) =>
      values.firstWhere((t) => t.value == v, orElse: () => user);
}

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    required this.isActive,
    this.createdAt,
  });

  factory AppUser.fromJson(Json json) {
    final j = json.unwrapData();
    return AppUser(
      id: j.str('id'),
      name: j.str('name'),
      email: j.str('email'),
      type: UserType.fromValue(j.strOrNull('user_type')),
      isActive: j.boolean('is_active', fallback: true),
      createdAt: j.date('created_at'),
    );
  }

  final String id;
  final String name;
  final String email;
  final UserType type;
  final bool isActive;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, email, type, isActive];
}

abstract interface class UserRepository {
  Future<Paginated<AppUser>> list({PageQuery page = const PageQuery()});
  Future<AppUser> create({
    required String name,
    required String email,
    required String password,
    required UserType type,
  });
  Future<AppUser> update(String id, {String? name, bool? isActive});
  Future<void> delete(String id);
}
