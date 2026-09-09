import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final String title;
  final String url;
  final String storagePath;

  const DocumentPreviewScreen({
    super.key,
    required this.title,
    required this.url,
    required this.storagePath,
  });

  String get _ext {
    final clean = storagePath.toLowerCase().split('?').first;
    final dot = clean.lastIndexOf('.');
    return dot == -1 ? '' : clean.substring(dot + 1);
  }

  bool get _isImage => const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}.contains(_ext);
  bool get _isPdf => _ext == 'pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _isImage
          ? Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const _PreviewError(message: 'Could not load this image.'),
                ),
              ),
            )
          : _isPdf
              ? PdfViewer.uri(Uri.parse(url))
              : _UnsupportedPreview(title: title, extension: _ext),
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  final String title;
  final String extension;
  const _UnsupportedPreview({required this.title, required this.extension});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.insert_drive_file_outlined, size: 54),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  extension.isEmpty
                      ? 'This file type does not have an in-app preview yet.'
                      : '${extension.toUpperCase()} files do not have an in-app preview yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _PreviewError extends StatelessWidget {
  final String message;
  const _PreviewError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.broken_image_outlined, size: 48),
          const SizedBox(height: 10),
          Text(message),
        ]),
      );
}
