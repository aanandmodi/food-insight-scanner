import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production service for uploading user images (avatars, food scans) to 100% Free Supabase Storage.
/// No credit card or paid upgrade required.
class SupabaseStorageService {
  static final SupabaseStorageService _instance = SupabaseStorageService._internal();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._internal();

  bool _isInitialized = false;
  static const String defaultBucket = 'food-insight-uploads';

  /// Initialize Supabase with your project URL and public anon key.
  /// Call this in main() or when storage is first accessed.
  Future<void> initialize({
    required String supabaseUrl,
    required String anonKey,
  }) async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: anonKey,
      );
      _isInitialized = true;
      debugPrint('SupabaseStorageService: Initialized successfully.');
    } catch (e) {
      debugPrint('SupabaseStorageService initialization error: $e');
    }
  }

  bool get isReady {
    try {
      return _isInitialized || Supabase.instance.client != null;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase client unavailable: $e');
      return null;
    }
  }

  /// Uploads user profile avatar to Supabase Storage: food-insight-uploads/users/{userId}/avatar.jpg
  Future<String?> uploadProfileAvatar({
    required String userId,
    required File imageFile,
    String bucketName = defaultBucket,
  }) async {
    final client = _client;
    if (client == null) {
      debugPrint('SupabaseStorageService: Client not initialized.');
      return null;
    }

    try {
      final fileExtension = imageFile.path.split('.').last;
      final path = 'users/$userId/avatar.$fileExtension';

      await client.storage.from(bucketName).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final publicUrl = client.storage.from(bucketName).getPublicUrl(path);
      debugPrint('Supabase profile avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase avatar upload error: $e');
      return null;
    }
  }

  /// Uploads a meal/product scan snapshot to Supabase Storage: food-insight-uploads/users/{userId}/scans/{scanId}.jpg
  Future<String?> uploadScanSnapshot({
    required String userId,
    required String scanId,
    required File imageFile,
    String bucketName = defaultBucket,
  }) async {
    final client = _client;
    if (client == null) {
      debugPrint('SupabaseStorageService: Client not initialized.');
      return null;
    }

    try {
      final fileExtension = imageFile.path.split('.').last;
      final path = 'users/$userId/scans/$scanId.$fileExtension';

      await client.storage.from(bucketName).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final publicUrl = client.storage.from(bucketName).getPublicUrl(path);
      debugPrint('Supabase scan snapshot uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase scan upload error: $e');
      return null;
    }
  }

  /// Deletes a file from Supabase storage by path
  Future<bool> deleteFile({
    required String path,
    String bucketName = defaultBucket,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.storage.from(bucketName).remove([path]);
      return true;
    } catch (e) {
      debugPrint('Supabase file deletion error: $e');
      return false;
    }
  }
}
