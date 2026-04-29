import 'package:edumap_portfolio_project/features/profile/views/view_models/profile_provider.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/profile/repositories/profile_repository.dart';

final profileStreamProvider = StreamProvider.family<ProfileState, String?>((
  ref,
  userId,
) async* {
  yield const ProfileState(loading: true);

  final authRepo = ref.read(authRepositoryProvider);
  final targetUserId = userId ?? authRepo.currentUser?.id;

  if (targetUserId == null) {
    yield const ProfileState(loading: false, errorMessage: 'Not logged in.');
    return;
  }

  final firestore = FirebaseFirestore.instance;
  final repository = ProfileRepository();

  try {
    
    final query = firestore
        .collection('profiles')
        .where('user_id', isEqualTo: targetUserId)
        .limit(1);

    await for (final snapshot in query.snapshots()) {
      if (snapshot.docs.isEmpty) {
        yield const ProfileState(
          loading: false,
          errorMessage: 'Profile not found.',
        );
      } else {
        final doc = snapshot.docs.first;
        final profile = repository.fromSnapshot(doc);
        yield ProfileState(profile: profile, loading: false);
      }
    }
  } catch (e) {
    yield ProfileState(loading: false, errorMessage: e.toString());
  }
});