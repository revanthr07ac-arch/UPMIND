import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (AppConfig.isSupabaseConfigured) {
    return Supabase.instance.client;
  }
  // Return instance if already initialized, or create client instance
  try {
    return Supabase.instance.client;
  } catch (_) {
    return SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
  }
});
