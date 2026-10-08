import 'package:equatable/equatable.dart';

/// Erro tipado da API SpoolIQ.
///
/// Corpo padrão: `{error, message, code, fields?}` — `code` é string
/// snake_case (o schema do swagger com `code` inteiro está desatualizado).
sealed class ApiError extends Equatable implements Exception {
  const ApiError(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  List<Object?> get props => [runtimeType, message, code, statusCode];

  @override
  String toString() => 'ApiError($statusCode, $code): $message';
}

/// Sem conexão, timeout ou DNS.
final class NetworkError extends ApiError {
  const NetworkError([
    super.message =
        'Não foi possível conectar ao servidor. '
        'Verifique sua conexão.',
  ]);
}

/// 401 — sessão inválida/expirada.
final class UnauthorizedError extends ApiError {
  const UnauthorizedError([
    super.message = 'Sua sessão expirou. Entre novamente.',
    String? code,
  ]) : super(code: code, statusCode: 401);
}

/// 403 por papel insuficiente.
final class ForbiddenError extends ApiError {
  const ForbiddenError(super.message, {super.code}) : super(statusCode: 403);
}

/// 402/403 do gate de assinatura (trial expirado, pagamento pendente…).
final class SubscriptionError extends ApiError {
  const SubscriptionError(
    super.message, {
    required super.code,
    super.statusCode,
  });

  static const codes = {
    'trial_expired',
    'payment_pending',
    'subscription_suspended',
    'subscription_cancelled',
  };
}

/// 400 `validation_error`, com mensagens por campo.
final class ValidationError extends ApiError {
  const ValidationError(super.message, {this.fields = const {}, super.code})
    : super(statusCode: 400);

  final Map<String, String> fields;

  @override
  List<Object?> get props => [...super.props, fields];
}

/// 404.
final class NotFoundError extends ApiError {
  const NotFoundError(super.message, {super.code}) : super(statusCode: 404);
}

/// 409 — conflito de estado (ex.: `budget_status_conflict`).
final class ConflictError extends ApiError {
  const ConflictError(super.message, {super.code}) : super(statusCode: 409);
}

/// Demais 4xx de regra de negócio (ex.: `invalid_status_transition`).
final class BusinessError extends ApiError {
  const BusinessError(super.message, {super.code, super.statusCode});
}

/// 5xx ou resposta inesperada.
final class ServerError extends ApiError {
  const ServerError([
    super.message = 'Ocorreu um erro no servidor. Tente novamente.',
    int? statusCode,
    String? code,
  ]) : super(statusCode: statusCode, code: code);
}

/// Constrói o [ApiError] adequado a partir do status e do corpo.
ApiError apiErrorFrom(int? status, Object? body) {
  final map = body is Map
      ? Map<String, dynamic>.from(body)
      : const <String, dynamic>{};
  final code = map['code']?.toString();
  final raw = (map['message'] ?? map['error'])?.toString();
  final message = (raw == null || raw.isEmpty) ? null : raw;

  if (code != null && SubscriptionError.codes.contains(code)) {
    return SubscriptionError(
      message ?? 'Sua assinatura precisa de atenção.',
      code: code,
      statusCode: status,
    );
  }

  return switch (status) {
    401 => UnauthorizedError(
      message ?? 'Sua sessão expirou. Entre novamente.',
      code,
    ),
    402 => SubscriptionError(
      message ?? 'Sua assinatura precisa de atenção.',
      code: code ?? 'payment_required',
      statusCode: 402,
    ),
    403 => ForbiddenError(
      message ?? 'Você não tem permissão para esta ação.',
      code: code,
    ),
    404 => NotFoundError(message ?? 'Registro não encontrado.', code: code),
    409 => ConflictError(
      message ?? 'O registro foi alterado por outra pessoa. Recarregue.',
      code: code,
    ),
    400 when code == 'validation_error' || map['fields'] is Map =>
      ValidationError(
        message ?? 'Verifique os campos destacados.',
        code: code,
        fields: {
          for (final e
              in ((map['fields'] as Map?) ?? const <String, dynamic>{}).entries)
            e.key.toString(): e.value.toString(),
        },
      ),
    final int s when s >= 400 && s < 500 => BusinessError(
      message ?? 'Não foi possível concluir a ação.',
      code: code,
      statusCode: s,
    ),
    _ => ServerError(
      message ?? 'Ocorreu um erro no servidor. Tente novamente.',
      status,
      code,
    ),
  };
}
