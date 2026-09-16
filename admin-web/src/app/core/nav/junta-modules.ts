export type JuntaNavSection = 'moderation' | 'community' | 'platform';

export type JuntaModuleId =
  | 'overview'
  | 'topics'
  | 'rejected-topics'
  | 'reports'
  | 'events'
  | 'close-requests'
  | 'conversations'
  | 'news'
  | 'moderators'
  | 'hermandades'
  | 'forums'
  | 'season'
  | 'ads'
  | 'companies'
  | 'finance'
  | 'quiz'
  | 'notifications'
  | 'demo-world'
  | 'users';

export interface JuntaModuleDef {
  id: JuntaModuleId;
  label: string;
  shortLabel: string;
  route: string;
  section: JuntaNavSection | null;
  adminOnly: boolean;
  /** Extra: no está aún en la Junta móvil. */
  webOnly?: boolean;
  comingSoon?: boolean;
}

export const JUNTA_SECTION_TITLES: Record<JuntaNavSection, string> = {
  moderation: 'Moderación',
  community: 'Comunidad',
  platform: 'Plataforma',
};

export const JUNTA_MODULES: JuntaModuleDef[] = [
  {
    id: 'overview',
    label: 'Resumen',
    shortLabel: 'Resumen',
    route: '/app/resumen',
    section: null,
    adminOnly: false,
  },
  {
    id: 'topics',
    label: 'Temas pendientes',
    shortLabel: 'Temas',
    route: '/app/temas',
    section: 'moderation',
    adminOnly: false,
    comingSoon: false,
  },
  {
    id: 'rejected-topics',
    label: 'Historial de rechazos',
    shortLabel: 'Rechazos',
    route: '/app/rechazos',
    section: 'moderation',
    adminOnly: false,
    comingSoon: false,
  },
  {
    id: 'reports',
    label: 'Reportes',
    shortLabel: 'Reportes',
    route: '/app/reportes',
    section: 'moderation',
    adminOnly: false,
    comingSoon: false,
  },
  {
    id: 'events',
    label: 'Eventos',
    shortLabel: 'Eventos',
    route: '/app/eventos',
    section: 'moderation',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'close-requests',
    label: 'Cierres solicitados',
    shortLabel: 'Cierres',
    route: '/app/cierres',
    section: 'moderation',
    adminOnly: false,
    comingSoon: false,
  },
  {
    id: 'conversations',
    label: 'Conversaciones',
    shortLabel: 'Hilos',
    route: '/app/conversaciones',
    section: 'moderation',
    adminOnly: false,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'news',
    label: 'Noticias',
    shortLabel: 'Noticias',
    route: '/app/noticias',
    section: 'community',
    adminOnly: false,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'users',
    label: 'Usuarios y altas',
    shortLabel: 'Usuarios',
    route: '/app/usuarios',
    section: 'community',
    adminOnly: true,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'moderators',
    label: 'Moderadores',
    shortLabel: 'Moderadores',
    route: '/app/moderadores',
    section: 'community',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'hermandades',
    label: 'Hermandades',
    shortLabel: 'Hermandades',
    route: '/app/hermandades',
    section: 'community',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'forums',
    label: 'Foros y apariencia',
    shortLabel: 'Foros',
    route: '/app/foros',
    section: 'community',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'season',
    label: 'Temporada',
    shortLabel: 'Temporada',
    route: '/app/temporada',
    section: 'platform',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'ads',
    label: 'Patrocinios',
    shortLabel: 'Patrocinios',
    route: '/app/patrocinios',
    section: 'platform',
    adminOnly: true,
    comingSoon: false,
  },
  {
    id: 'companies',
    label: 'Empresas',
    shortLabel: 'Empresas',
    route: '/app/empresas',
    section: 'platform',
    adminOnly: true,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'finance',
    label: 'Finanzas',
    shortLabel: 'Finanzas',
    route: '/app/finanzas',
    section: 'platform',
    adminOnly: true,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'quiz',
    label: 'Pregunta en vivo',
    shortLabel: 'Quiz',
    route: '/app/quiz',
    section: 'platform',
    adminOnly: false,
    comingSoon: false,
  },
  {
    id: 'notifications',
    label: 'Notificaciones',
    shortLabel: 'Avisos',
    route: '/app/notificaciones',
    section: 'platform',
    adminOnly: true,
    webOnly: true,
    comingSoon: false,
  },
  {
    id: 'demo-world',
    label: 'Simulación',
    shortLabel: 'Simulación',
    route: '/app/simulacion',
    section: 'platform',
    adminOnly: true,
    webOnly: true,
    comingSoon: false,
  },
];

export function visibleModules(isAdmin: boolean): JuntaModuleDef[] {
  return JUNTA_MODULES.filter((m) => {
    if (m.id === 'overview') return true;
    if (m.adminOnly && !isAdmin) return false;
    return true;
  });
}
