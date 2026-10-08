import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Par de tokens retornado por `/login` e `/refresh`.
class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];
}

/// Persistência dos tokens.
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Keychain (macOS) / Credential Manager (Windows).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Keychain legado: funciona em builds sem time de assinatura
            // (o Data Protection Keychain exige keychain-access-groups).
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  static const _accessKey = 'spooliq.access_token';
  static const _refreshKey = 'spooliq.refresh_token';

  AuthTokens? _cache;

  @override
  Future<AuthTokens?> read() async {
    if (_cache != null) return _cache;
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || access.isEmpty) return null;
    return _cache = AuthTokens(
      accessToken: access,
      refreshToken: refresh ?? '',
    );
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cache = tokens;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Implementação em memória para testes.
class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;

  @override
  Future<void> clear() async => tokens = null;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;
}
