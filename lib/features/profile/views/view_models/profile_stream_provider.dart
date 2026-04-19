// lib/features/profile/views/view_models/profile_stream_provider.dart
import 'dart:async';
import 'package:flutter_education_app/features/profile/views/view_models/profile_provider.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileStreamProvider = StreamProvider.family<ProfileState, String?>((
  ref,
  userId,
) async* {
  yield const ProfileState(loading: true);

  try {
    final notifier = ref.read(profileProvider(userId).notifier);
    await notifier.loadProfile();
    final state = ref.read(profileProvider(userId));
    yield state;
  } catch (e) {
    yield ProfileState(loading: false, errorMessage: e.toString());
    return;
  }

  final controller = StreamController<ProfileState>();

  final timer = Timer.periodic(const Duration(seconds: 30), (_) async {
    try {
      final notifier = ref.read(profileProvider(userId).notifier);
      await notifier.loadProfile();
      final state = ref.read(profileProvider(userId));
      controller.add(state);
    } catch (e) {
      controller.add(ProfileState(loading: false, errorMessage: e.toString()));
    }
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  yield* controller.stream;
});
