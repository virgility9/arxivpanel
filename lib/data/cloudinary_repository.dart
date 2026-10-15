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
  /// Uploads a PDF and returns its `secure_url`.
  Future<String> uploadPdf(Uint8List bytes, String fileName) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${CloudinaryConfig.cloudName}/raw/upload',
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
    if (url == null || url.isEmpty) {
      throw StateError('Cloudinary upload returned no URL');
    }
    return url;
  }
}
