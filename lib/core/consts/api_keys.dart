import 'package:flutter_dotenv/flutter_dotenv.dart';


final String supabaseUrl = dotenv.env['SUPABASE_URL']!;
final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
final String stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
final String urlTemplate = dotenv.env['URL_TEMPLATE']!;
final String openStreetMapApiUrl = dotenv.env['OPEN_STREET_MAP_API_URL']!;
final String supabaseGoogleClientIdWeb =
    dotenv.env['SUPABASE_GOOGLE_CLIENT_ID_WEB']!;
final String zegoAppId = dotenv.env['ZEGO_APP_ID']!;


String getEnvFile() {
  const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'development',
  );

  switch (flavor) {
    case 'production':
      return '.env.production';
    case 'staging':
      return '.env.local';
    case 'development':
    default:
      return '.env.development';
  }
}

void validateEnvironmentVariables() {
  final requiredKeys = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'STRIPE_PUBLISHABLE_KEY',
    'ZEGO_APP_ID',
    'URL_TEMPLATE',
    'OPEN_STREET_MAP_API_URL',
    'SUPABASE_GOOGLE_CLIENT_ID_WEB',
  ];

  final missingKeys = <String>[];
  for (final key in requiredKeys) {
    if (dotenv.env[key]?.isEmpty ?? true) {
      missingKeys.add(key);
    }
  }

  if (missingKeys.isNotEmpty) {
    final flavor = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );
    throw Exception(
      'Missing required environment variables in .env.$flavor:\n'
      '${missingKeys.join(', ')}\n\n'
      'Please ensure your .env.$flavor file contains all required keys.',
    );
  }
}

