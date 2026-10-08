import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// E-mail e senha lembrados para o login rápido.
class SavedCredentials extends Equatable {
  const SavedCredentials({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email];
}

/// Falha da autenticação do sistema que o usuário precisa ver (bloqueio,
/// biometria não cadastrada…). Cancelar o prompt não gera erro.
class VaultError implements Exception {
  const VaultError(this.message);

  final String message;

  @override
  String toString() => 'VaultError($message)';
}

/// Guarda as credenciais no Keychain (macOS) / Credential Manager (Windows)
/// e só as devolve após Touch ID / Windows Hello.
abstract interface class CredentialVault {
  /// Nome do método do sistema ("Touch ID", "Windows Hello") ou null quando
  /// o dispositivo não oferece autenticação local.
  Future<String?> methodLabel();

  /// E-mail salvo, sem pedir autenticação (para preencher o campo).
  Future<String?> savedEmail();

  /// Pede autenticação e devolve as credenciais; null se o usuário cancelar
  /// ou não houver nada salvo. Lança [VaultError] em falhas do sistema.
  Future<SavedCredentials?> unlock();

  Future<void> save(SavedCredentials credentials);

  Future<void> clear();
}

class BiometricCredentialVault implements CredentialVault {
  BiometricCredentialVault({
    FlutterSecureStorage? storage,
    LocalAuthentication? auth,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             // Mesmo motivo do SecureTokenStore: builds sem time de assinatura.
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           ),
       _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _emailKey = 'spooliq.saved_email';
  static const _passwordKey = 'spooliq.saved_password';

  @override
  Future<String?> methodLabel() async {
    try {
      if (!await _auth.isDeviceSupported()) return null;
    } on Exception {
      return null;
    }
    return Platform.isWindows ? 'Windows Hello' : 'Touch ID';
  }

  @override
  Future<String?> savedEmail() => _storage.read(key: _emailKey);

  @override
  Future<SavedCredentials?> unlock() async {
    final email = await _storage.read(key: _emailKey);
    if (email == null) return null;
    final bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: 'entrar no SpoolIQ como $email',
      );
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return null;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          throw const VaultError(
            'Autenticação bloqueada por excesso de tentativas. '
            'Entre com e-mail e senha.',
          );
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
          throw const VaultError(
            'Nenhuma biometria configurada neste computador.',
          );
        // ignore: no_default_cases — os demais códigos são falhas genéricas.
        default:
          throw VaultError(
            'Não foi possível autenticar (${e.code.name}). '
            'Entre com e-mail e senha.',
          );
      }
    }
    if (!ok) return null;
    final password = await _storage.read(key: _passwordKey);
    if (password == null) return null;
    return SavedCredentials(email: email, password: password);
  }

  @override
  Future<void> save(SavedCredentials credentials) async {
    await _storage.write(key: _emailKey, value: credentials.email);
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
