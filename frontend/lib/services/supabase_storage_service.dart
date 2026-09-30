import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'user_session.dart';

class SupabaseStorageService {
  static final _instance = SupabaseStorageService._();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._();
  static const defaultBucket = 'food-insight-private';
  bool get isReady => UserSession.instance.uid != null;
  Future<void> initialize() async {}
  Future<void> ensureInitialized() async {}
  Future<String?> _upload(
      String userId, File file, String suffix, String bucket) async {
    final session = UserSession.instance.capture();
    if (session.uid != userId) {
      throw StateError('Cannot upload to another account');
    }
    final extension = file.path.split('.').last.toLowerCase();
    final ext = extension == 'png' || extension == 'webp' ? extension : 'jpg';
    final path = 'users/$userId/$suffix.$ext';
    await SupabaseService.client.storage.from(bucket).upload(path, file,
        fileOptions: FileOptions(
            upsert: true,
            contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
    session.check();
    // Persist the object reference, not an expiring signed URL.
    return 'supabase://$bucket/$path';
  }

  Future<String?> uploadProfileAvatar(
          {required String userId,
          required File imageFile,
          String bucketName = defaultBucket}) =>
      _upload(userId, imageFile, 'avatar', bucketName);
  Future<String?> uploadScanSnapshot(
          {required String userId,
          required String scanId,
          required File imageFile,
          String bucketName = defaultBucket}) =>
      _upload(userId, imageFile, 'scans/${Uri.encodeComponent(scanId)}',
          bucketName);
  static bool needsSignedUrl(String reference) =>
      reference.startsWith('supabase://') ||
      reference.startsWith(
          '${SupabaseService.url}/storage/v1/object/public/food-insight-uploads/');
  Future<String> resolveUrl(String reference) async {
    if (!needsSignedUrl(reference)) return reference;
    reference = reference.replaceFirst(
        '${SupabaseService.url}/storage/v1/object/public/', 'supabase://');
    final session = UserSession.instance.capture();
    final uri = Uri.parse(reference);
    final path = uri.path.substring(1);
    if (!path.startsWith('users/${session.uid}/')) {
      throw StateError('Cannot read another account image');
    }
    final url = await SupabaseService.client.storage
        .from(uri.host)
        .createSignedUrl(path, 3600);
    session.check();
    return url;
  }

  Future<bool> deleteFile(
      {required String path, String bucketName = defaultBucket}) async {
    final session = UserSession.instance.capture();
    if (!path.startsWith('users/${session.uid}/')) {
      throw StateError('Cannot delete another account image');
    }
    await SupabaseService.client.storage.from(bucketName).remove([path]);
    session.check();
    return true;
  }
}
