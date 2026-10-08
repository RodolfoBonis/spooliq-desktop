import 'package:spooliq_desktop/core/auth/session_user.dart';

/// Dados de cadastro de conta + empresa (`POST /register`).
class RegisterData {
  const RegisterData({
    required this.name,
    required this.email,
    required this.password,
    required this.companyName,
    required this.companyDocument,
    required this.companyPhone,
    required this.address,
    required this.addressNumber,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.zipCode,
    this.companyTradeName,
    this.complement,
  });

  final String name;
  final String email;
  final String password;
  final String companyName;
  final String? companyTradeName;
  final String companyDocument;
  final String companyPhone;
  final String address;
  final String addressNumber;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;
  final String zipCode;
}

abstract interface class AuthRepository {
  /// Sessão persistida (tokens no cofre do SO), se ainda utilizável.
  Future<SessionUser?> restore();

  Future<SessionUser> login({required String email, required String password});

  Future<void> register(RegisterData data);

  Future<void> logout();
}
