/// Aceita apenas URLs https da InfinitePay (checkout e recibos).
///
/// Espelha a validação do web (`sanitizeHttpUrl` + host `infinitepay.io`):
/// nada interno é aberto a partir de um link devolvido pela API. Rejeita
/// esquemas não-https, userinfo embutido (`https://x@evil.com`), hosts que só
/// terminam parecido (`infinitepay.io.evil.com`) e FQDN com ponto final.
bool isInfinitePayUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  // Userinfo é um vetor clássico de disfarce de host: recusamos.
  if (uri.userInfo.isNotEmpty) return false;
  final host = uri.host.toLowerCase();
  return host == 'infinitepay.io' || host.endsWith('.infinitepay.io');
}
