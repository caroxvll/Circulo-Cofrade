import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { environment } from '../../environments/environment';

let client: SupabaseClient | null = null;

export function isSupabaseConfigured(): boolean {
  return Boolean(environment.supabaseUrl && environment.supabaseAnonKey);
}

export function getSupabase(): SupabaseClient {
  if (!isSupabaseConfigured()) {
    throw new Error(
      'Supabase no configurado. Ejecuta npm run sync-env o rellena environment.local.ts',
    );
  }
  if (!client) {
    client = createClient(environment.supabaseUrl, environment.supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
  }
  return client;
}
