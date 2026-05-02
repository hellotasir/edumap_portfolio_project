import 'package:flutter_dotenv/flutter_dotenv.dart';

final String supabaseUrl = dotenv.env['SUPABASE_URL']!;
final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
final String stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
final String urlTemplate = dotenv.env['URL_TEMPLATE']!;
final String openStreetMapApiUrl = dotenv.env['OPEN_STREET_MAP_API_URL']!;
final String supabaseGoogleClientIdWeb =
    dotenv.env['SUPABASE_GOOGLE_CLIENT_ID_WEB']!;
