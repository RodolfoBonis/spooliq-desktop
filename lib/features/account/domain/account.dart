import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Perfil do usuário logado (`GET /me`).
class Me extends Equatable {
  const Me({
    required this.id,
    required this.name,
    required this.email,
    this.userType,
  });

  factory Me.fromJson(Json json) => Me(
    id: json.str('id'),
    name: json.str('name'),
    email: json.str('email'),
    userType: json.strOrNull('user_type'),
  );

  final String id;
  final String name;
  final String email;
  final String? userType;

  @override
  List<Object?> get props => [id, name, email, userType];
}

abstract interface class AccountRepository {
  /// Pede o e-mail de redefinição. Não revela se o e-mail existe.
  Future<void> forgotPassword(String email);

  Future<Me> me();

  Future<Me> updateName(String name);

  Future<void> changePassword({
    required String current,
    required String newPassword,
  });
}
