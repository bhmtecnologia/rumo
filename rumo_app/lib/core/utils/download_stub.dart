/// Stub: em plataformas não-web, não faz download (use a versão web para exportar).
void downloadFile(String filename, String content, String mimeType) {
  // No-op; em mobile/desktop o usuário pode usar a versão web para exportar.
}

void downloadBytes(String filename, List<int> bytes, String mimeType) {
  // No-op
}
