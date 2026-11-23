import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:core/src/config/core_config.dart';

class CloudinaryUploadService {
  // Cloud name + upload preset from environment config (Law 3: Single Source
  // of Truth, Law 16: Secret Guarding). No hardcoded account identifiers.
  static String get _cloudName => CoreConfigHolder.instance.cloudinaryCloudName;
  static String get _uploadPreset =>
      CoreConfigHolder.instance.cloudinaryUploadPreset;

  static final ImagePicker _picker = ImagePicker();

  /// PERF-10 T-8 test seam. The upload POST previously went through
  /// `MultipartRequest.send()`, which builds its own `http.Client` internally
  /// and is therefore un-injectable. Production behaviour is unchanged — the
  /// default is a real client, exactly what `send()` created — while tests
  /// inject `package:http/testing.dart`'s `MockClient` to assert the multipart
  /// shape and the 200 / non-200 branches with zero network I/O.
  static http.Client? debugClientOverride;

  static http.Client get _client => debugClientOverride ?? http.Client();

  /// Prompts the user to pick an image from their gallery, then uploads
  /// to Cloudinary via unsigned POST and returns the secure URL.
  static Future<String?> pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // Compress massive 4K phone photos before uploading
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      return _uploadToCloudinary(bytes, image.name);
    } catch (e) {
      // Re-throw to be handled by the UI snackbar
      throw Exception('Image selection failed: $e');
    }
  }

  /// PERF-10 T-8 test seam: the HTTP leg of [pickAndUploadImage] without the
  /// platform image picker (which cannot run under `flutter test`). Adds no
  /// production caller — the public entry point is unchanged.
  @visibleForTesting
  static Future<String> uploadToCloudinaryForTest(
    List<int> bytes,
    String filename,
  ) => _uploadToCloudinary(bytes, filename);

  static Future<String> _uploadToCloudinary(
    List<int> bytes,
    String filename,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = _uploadPreset;

    // Add the image bytes
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(responseBody) as Map<String, dynamic>;
      return jsonResponse['secure_url'] as String;
    } else {
      throw Exception(
        'Cloudinary upload failed: ${response.statusCode} - $responseBody',
      );
    }
  }
}
