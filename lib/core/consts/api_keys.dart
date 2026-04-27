import 'package:flutter_dotenv/flutter_dotenv.dart';

final String stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
final String supabaseUrl = dotenv.env['SUPABASE_URL']!;
final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
final String sslCommerzStoreID = dotenv.env['SSL_COMMERZ_STORE_ID']!;
final String sslCommerzStorePassword =
    dotenv.env['SSL_COMMERZ_STORE_PASSWORD']!;
final String urlTemplate = dotenv.env['URL_TEMPLATE']!;
final String openStreetMapApiUrl = dotenv.env['OPEN_STREET_MAP_API_URL']!;
final String supabaseGoogleClientIdWeb =
    dotenv.env['SUPABASE_GOOGLE_CLIENT_ID_WEB']!;
