class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  // Número internacional sem +, espaços ou pontuação. Ex.: 5511999999999.
  static const supportWhatsappNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
  );

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  }
}
