import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Production service for managing user Cloud Storage uploads in isolated UID folders.
class CloudStorageService {
  static final CloudStorageService _instance = CloudStorageService._internal();
  factory CloudStorageService() => _instance;
  CloudStorageService._internal();

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseStorage? get _storage {
    if (!_isFirebaseReady) return null;
    try {
      return FirebaseStorage.instance;
    } catch (e) {
      debugPrint('FirebaseStorage unavailable: $e');
      return null;
    }
  }

  String? get _userId {
    if (!_isFirebaseReady) return null;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      debugPrint('Auth unavailable: $e');
      return null;
    }
  }

  /// Uploads user profile avatar image to users/{userId}/profile/avatar.jpg
  Future<String?> uploadProfileAvatar(File imageFile) async {
    final uid = _userId;
    final storage = _storage;
    if (uid == null || storage == null) {
      debugPrint('CloudStorage: User unauthenticated or storage unavailable.');
      return null;
    }

    try {
      final ref = storage.ref().child('users/$uid/profile/avatar.jpg');
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile avatar: $e');
      return null;
    }
  }

  /// Uploads a meal/product scan snapshot to users/{userId}/scans/{scanId}.jpg
  Future<String?> uploadScanSnapshot(String scanId, File imageFile) async {
    final uid = _userId;
    final storage = _storage;
    if (uid == null || storage == null) {
      debugPrint('CloudStorage: User unauthenticated or storage unavailable.');
      return null;
    }

    try {
      final ref = storage.ref().child('users/$uid/scans/$scanId.jpg');
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading scan snapshot: $e');
      return null;
    }
  }

  /// Deletes a file at the given storage URL or reference path
  Future<bool> deleteFile(String pathOrUrl) async {
    final storage = _storage;
    if (storage == null) return false;

    try {
      final ref = pathOrUrl.startsWith('http')
          ? storage.refFromURL(pathOrUrl)
          : storage.ref().child(pathOrUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting file from storage: $e');
      return false;
    }
  }
}
