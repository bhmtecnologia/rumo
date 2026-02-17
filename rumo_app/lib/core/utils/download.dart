import 'download_stub.dart' if (dart.library.html) 'download_web.dart' as impl;

void downloadFile(String filename, String content, String mimeType) {
  impl.downloadFile(filename, content, mimeType);
}

void downloadBytes(String filename, List<int> bytes, String mimeType) {
  impl.downloadBytes(filename, bytes, mimeType);
}
