import { environmentLocal } from './environment.local';

export const environment = {
  production: false,
  supabaseUrl: environmentLocal.supabaseUrl,
  supabaseAnonKey: environmentLocal.supabaseAnonKey,
};
