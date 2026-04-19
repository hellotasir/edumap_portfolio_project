import 'package:flutter_education_app/features/app/repositories/storage_repository.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_notifier.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/core/services/cloud/database_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final firestoreServiceProvider = Provider<DatabaseService<ProfileModel>>(
  (_) => DatabaseService<ProfileModel>(ProfileRepository()),
);

final storageServiceProvider = Provider<StorageRepository>(
  (_) => StorageRepository(),
);

final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser?.id;
});

enum UploadTarget { avatar, cover }

final profileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileState, String?>(
      (ref, viewUserId) => ProfileNotifier(ref: ref, viewUserId: viewUserId),
    );
