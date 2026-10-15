/// Firebase Storage uploads: profile avatars and paper PDFs.
///
/// Requires the Blaze plan — file uploads are not available on Spark.
/// Callers should surface a friendly message when uploads fail (most
/// commonly: Storage not enabled yet). See `storage.rules` (repo root) for
/// the matching security rules and FIREBASE_SETUP.md for the console steps.
library;

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageRepository {
  StorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads an avatar image for [uid] and returns its public download URL.
  ///
  /// [extension] should be the picked file's extension (`jpg`, `png`,
  /// `gif`, `webp`); anything else is stored as JPEG.
  Future<String> uploadAvatar(
    String uid,
    Uint8List bytes,
    String extension,
  ) async {
    final ext = _imageExtension(extension);
    final ref = _storage.ref('avatars/$uid.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    return ref.getDownloadURL();
  }

  /// Uploads a paper PDF and returns its public download URL.
  Future<String> uploadPaperPdf(
    String paperId,
    Uint8List bytes,
    String originalName,
  ) async {
    final ref = _storage.ref('paper-pdfs/$paperId.pdf');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'originalName': originalName},
      ),
    );
    return ref.getDownloadURL();
  }

  String _imageExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
