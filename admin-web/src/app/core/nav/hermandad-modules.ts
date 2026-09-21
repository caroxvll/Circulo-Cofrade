export type HermandadModuleId = 'home' | 'publish' | 'posts';

export interface HermandadNavItem {
  id: HermandadModuleId;
  label: string;
  route: string;
}

export const HERMANDAD_NAV: readonly HermandadNavItem[] = [
  { id: 'home', label: 'Inicio', route: '/hermandad' },
  { id: 'publish', label: 'Publicar', route: '/hermandad/publicar' },
  { id: 'posts', label: 'Mis publicaciones', route: '/hermandad/publicaciones' },
] as const;
