/// Aceita apenas URLs https da InfinitePay (checkout e recibos).
///
/// Espelha a validação do web (`sanitizeHttpUrl` + host `infinitepay.io`):
/// nada interno é aberto a partir de um link devolvido pela API.
bool isInfinitePayUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  return host == 'infinitepay.io' || host.endsWith('.infinitepay.io');
}
