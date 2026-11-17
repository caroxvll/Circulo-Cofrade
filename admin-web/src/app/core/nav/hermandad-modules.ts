export type HermandadModuleId =
  | 'home'
  | 'calendar'
  | 'followers'
  | 'publish'
  | 'posts'
  | 'settings';

export interface HermandadNavItem {
  id: HermandadModuleId;
  label: string;
  route: string;
  /** Path SVG (viewBox 0 0 24 24) para el menú. */
  iconPath: string;
}

export const HERMANDAD_NAV: readonly HermandadNavItem[] = [
  {
    id: 'home',
    label: 'Inicio',
    route: '/hermandad',
    iconPath:
      'M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1v-9.5Z',
  },
  {
    id: 'calendar',
    label: 'Calendario',
    route: '/hermandad/calendario',
    iconPath:
      'M8 3v2M16 3v2M4 9h16M6 5h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2',
  },
  {
    id: 'followers',
    label: 'Seguidores',
    route: '/hermandad/seguidores',
    iconPath:
      'M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm7.5-1a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3.5 19c.8-2.8 2.8-4.2 5.5-4.2s4.7 1.4 5.5 4.2M14 15.2c1.2-.7 2.6-1 4-1 1.8 0 3.3.6 4.3 1.8',
  },
  {
    id: 'publish',
    label: 'Publicar',
    route: '/hermandad/publicar',
    iconPath: 'M12 5v14M5 12h14',
  },
  {
    id: 'posts',
    label: 'Mis publicaciones',
    route: '/hermandad/publicaciones',
    iconPath: 'M7 4h10v16l-5-2.5L7 20V4Z',
  },
  {
    id: 'settings',
    label: 'Ajustes',
    route: '/hermandad/ajustes',
    iconPath:
      'M5 8h8M5 16h8M15 8a2 2 0 1 0 4 0 2 2 0 0 0-4 0ZM7 16a2 2 0 1 0 4 0 2 2 0 0 0-4 0ZM17 16h2M3 8h2',
  },
] as const;
