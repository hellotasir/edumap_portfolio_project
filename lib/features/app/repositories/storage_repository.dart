import 'dart:io';
import 'package:edumap_portfolio_project/core/services/cloud/storage_service.dart';

class StorageResult<T> {
  final T? data;
  final String? error;

  const StorageResult.success(this.data) : error = null;
  const StorageResult.failure(this.error) : data = null;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

abstract class IStorageRepository {
  Future<StorageResult<String>> uploadChatMedia({
    required File file,
    required String senderId,
    required String folder,
  });

  Future<StorageResult<String>> uploadThumbnail({
    required File thumbnailFile,
    required String senderId,
  });

  Future<StorageResult<String>> uploadGroupPhoto({
    required File imageFile,
    required String adminUserId,
  });

  Future<StorageResult<String>> uploadAvatar({
    required String userId,
    required String roleLabel,
    required File file,
  });

  Future<StorageResult<String>> uploadCoverPhoto({
    required String userId,
    required File file,
  });

  Future<StorageResult<String>> getSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  });

  Future<StorageResult<void>> deleteFile(String storagePath);

  String avatarPath(String userId, String roleLabel, String ext);
  String coverPath(String userId, String ext);
}

class StorageRepository implements IStorageRepository {
  StorageRepository({StorageService? storageService})
    : _service = storageService ?? StorageService();

  final StorageService _service;

  @override
  Future<StorageResult<String>> uploadChatMedia({
    required File file,
    required String senderId,
    required String folder,
  }) async {
    try {
      final url = await _service.uploadChatMedia(
        file: file,
        senderId: senderId,
        folder: folder,
      );
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<String>> uploadThumbnail({
    required File thumbnailFile,
    required String senderId,
  }) async {
    try {
      final url = await _service.uploadThumbnail(
        thumbnailFile: thumbnailFile,
        senderId: senderId,
      );
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<String>> uploadGroupPhoto({
    required File imageFile,
    required String adminUserId,
  }) async {
    try {
      final url = await _service.uploadGroupPhoto(imageFile, adminUserId);
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<String>> uploadAvatar({
    required String userId,
    required String roleLabel,
    required File file,
  }) async {
    try {
      final url = await _service.uploadAvatar(userId, roleLabel, file);
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<String>> uploadCoverPhoto({
    required String userId,
    required File file,
  }) async {
    try {
      final url = await _service.uploadCoverPhoto(userId, file);
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<String>> getSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      final url = await _service.getSignedUrl(
        storagePath,
        expiresInSeconds: expiresInSeconds,
      );
      return StorageResult.success(url);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  Future<StorageResult<void>> deleteFile(String storagePath) async {
    try {
      await _service.deleteFile(storagePath);
      return const StorageResult.success(null);
    } catch (e) {
      return StorageResult.failure(e.toString());
    }
  }

  @override
  String avatarPath(String userId, String roleLabel, String ext) =>
      _service.avatarPath(userId, roleLabel, ext);

  @override
  String coverPath(String userId, String ext) =>
      _service.coverPath(userId, ext);
}
