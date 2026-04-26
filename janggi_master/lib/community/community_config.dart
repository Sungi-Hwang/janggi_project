class CommunityConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool isSupabaseInitialized = false;

  static bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  static bool get canUseSupabase {
    return isSupabaseConfigured && isSupabaseInitialized;
  }

  static bool get isGoogleConfigured {
    return googleWebClientId.isNotEmpty;
  }
}
