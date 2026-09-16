import { environmentLocal } from './environment.local';

export const environment = {
  production: true,
  supabaseUrl: environmentLocal.supabaseUrl,
  supabaseAnonKey: environmentLocal.supabaseAnonKey,
};
