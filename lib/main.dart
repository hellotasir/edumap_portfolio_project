import 'dart:async';
import 'package:edumap_portfolio_project/core/consts/api_keys.dart';
import 'package:edumap_portfolio_project/core/services/notification/notification_service.dart';
import 'package:edumap_portfolio_project/core/widgets/material_widget.dart';
import 'package:edumap_portfolio_project/features/app/error/error_handler.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/splash_screen.dart';
import 'package:edumap_portfolio_project/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}

final _errorHandler = ErrorHandler.instance;


void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final envFile = getEnvFile();
      await dotenv.load(fileName: envFile);
      validateEnvironmentVariables();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      sqfliteFfiInit();
      Stripe.publishableKey = stripePublishableKey;
      await Stripe.instance.applySettings();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await NotificationService.instance.initialize();
      await Permission.notification.request();
      await _errorHandler.initialize();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _errorHandler.onErrorDetails(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _errorHandler.onError(error, stack);
        return true;
      };

      runApp(const ProviderScope(child: MaterialWidget(child: MyApp())));

    },
    (error, stack) {
      _errorHandler.onError(error, stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}
