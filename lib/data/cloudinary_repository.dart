/// Paper PDF uploads via Cloudinary unsigned upload presets.
///
/// Free tier, no credit card required — the fallback upload host for users
/// without Firebase Blaze billing. See [CloudinaryConfig] for setup.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloudinary_config.dart';

class CloudinaryRepository {
  /// Uploads a PDF as an image-type resource (so Cloudinary can render its
  /// pages) and returns the file URL plus the public id.
  Future<({String fileUrl, String publicId})> uploadPdf(
    Uint8List bytes,
    String fileName,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: fileName));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError(
        'Cloudinary upload failed (${streamed.statusCode}): $body',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    final publicId = json['public_id'] as String?;
    if (url == null || url.isEmpty || publicId == null || publicId.isEmpty) {
      throw StateError('Cloudinary upload returned no URL');
    }
    return (fileUrl: url, publicId: publicId);
  }

  /// Cover image URL: the PDF's first page rendered as a 600px-wide JPEG.
  /// No extra upload — Cloudinary generates it on the fly.
  static String firstPageCover(String publicId) {
    final id =
        publicId.endsWith('.pdf') ? publicId.substring(0, publicId.length - 4) : publicId;
    return 'https://res.cloudinary.com/'
        '${CloudinaryConfig.cloudName}/image/upload/pg_1,w_600,f_jpg/$id.jpg';
  }
}
