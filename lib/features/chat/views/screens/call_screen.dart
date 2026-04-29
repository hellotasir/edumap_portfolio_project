import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({
    super.key,
    required this.userID,
    required this.userName,
    required this.callID,
    this.isVideoCall = true,
  });

  final String userID;
  final String userName;
  final String callID;
  final bool isVideoCall;

  int get _appID => int.parse(dotenv.env['ZEGO_APP_ID']!);
  String get _appSign => dotenv.env['ZEGO_APP_SIGN']!;

  @override
  Widget build(BuildContext context) {
    return NetworkWidget(
      child: ZegoUIKitPrebuiltCall(
        appID: _appID,
        appSign: _appSign,
        userID: userID,
        userName: userName,
        callID: callID,

        config: isVideoCall ? _videoCallConfig() : _voiceCallConfig(),

        events: ZegoUIKitPrebuiltCallEvents(
          onHangUpConfirmation: (event, defaultAction) async {
            final result = await _showEndDialog(context);
            return result == true ? await defaultAction() : false;
          },
          onCallEnd: (event, defaultAction) {
            debugPrint('Call Ended: ${event.reason}');
            defaultAction();
          },
        ),
      ),
    );
  }

  ZegoUIKitPrebuiltCallConfig _videoCallConfig() {
    final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    config.turnOnCameraWhenJoining = true;
    config.turnOnMicrophoneWhenJoining = true;
    config.useSpeakerWhenJoining = true;

    config.bottomMenuBar.buttons = [
      ZegoCallMenuBarButtonName.toggleCameraButton,
      ZegoCallMenuBarButtonName.toggleMicrophoneButton,
      ZegoCallMenuBarButtonName.switchCameraButton,
      ZegoCallMenuBarButtonName.hangUpButton,
    ];

    return config;
  }

  ZegoUIKitPrebuiltCallConfig _voiceCallConfig() {
    final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    config.turnOnCameraWhenJoining = false;
    config.turnOnMicrophoneWhenJoining = true;
    config.useSpeakerWhenJoining = false;

    config.bottomMenuBar.buttons = [
      ZegoCallMenuBarButtonName.toggleMicrophoneButton,
      ZegoCallMenuBarButtonName.switchAudioOutputButton,
      ZegoCallMenuBarButtonName.hangUpButton,
    ];

    return config;
  }

  Future<bool?> _showEndDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Call'),
        content: const Text('Are you sure you want to end the call?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
  }
}
