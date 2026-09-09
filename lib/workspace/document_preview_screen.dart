import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Uri get _downloadUri {
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'download': _downloadName,
    });
  }

  String get _downloadName {
    final cleanTitle = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (_ext.isEmpty || cleanTitle.toLowerCase().endsWith('.$_ext')) return cleanTitle.isEmpty ? 'document' : cleanTitle;
    return '${cleanTitle.isEmpty ? 'document' : cleanTitle}.$_ext';
  }

  Future<void> _download(BuildContext context) async {
    try {
      final opened = await launchUrl(_downloadUri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download this file.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not download this file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: () => _download(context),
            icon: const Icon(Icons.download_rounded),
          ),
          const SizedBox(width: 6),
        ],
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
              : _UnsupportedPreview(
                  title: title,
                  extension: _ext,
                  onDownload: () => _download(context),
                ),
    );
  }
}

class _UnsupportedPreview extends StatefulWidget {
  final String title;
  final String extension;
  final Future<void> Function() onDownload;

  const _UnsupportedPreview({
    required this.title,
    required this.extension,
    required this.onDownload,
  });

  @override
  State<_UnsupportedPreview> createState() => _UnsupportedPreviewState();
}

class _UnsupportedPreviewState extends State<_UnsupportedPreview> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await widget.onDownload();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  bool get _isZip => widget.extension.toLowerCase() == 'zip';

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isZip ? Icons.folder_zip_outlined : Icons.insert_drive_file_outlined, size: 54),
                const SizedBox(height: 14),
                Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  _isZip
                      ? 'ZIP archives cannot be previewed inside myDesk, but you can download the original archive.'
                      : widget.extension.isEmpty
                          ? 'This file type does not have an in-app preview yet, but you can download the original file.'
                          : '${widget.extension.toUpperCase()} files do not have an in-app preview yet, but you can download the original file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                  label: Text(_isZip ? 'Download ZIP' : 'Download file'),
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
