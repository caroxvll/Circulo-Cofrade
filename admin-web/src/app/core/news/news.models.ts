export const NOTICIAS_FORUM_ID = 'noticias';

/** Etiquetas temáticas (opción A). Se guardan en related_forum_id. */
export const NOTICIAS_RELATED_OPTIONS: { id: string; label: string }[] = [
  { id: 'consejo', label: 'Consejo / Institucional' },
  { id: 'hermandades', label: 'Hermandades' },
  { id: 'musica', label: 'Música' },
  { id: 'costaleros', label: 'Costaleros' },
  { id: 'cultura', label: 'Cultura / Patrimonio' },
];

export type NewsScheduleStatus = 'scheduled' | 'published' | 'cancelled';

export interface NewsTopic {
  id: string;
  title: string;
  excerpt: string;
  body: string;
  authorHandle: string | null;
  status: string;
  relatedForumId: string | null;
  coverImageUrl: string | null;
  createdAt: string;
  commentCount: number;
  newsGroupId: string | null;
}

export interface ScheduledNews {
  id: string;
  title: string;
  excerpt: string;
  body: string;
  authorHandle: string;
  relatedForumId: string | null;
  coverImageUrl: string | null;
  scheduledAt: string;
  status: NewsScheduleStatus;
  publishedTopicId: string | null;
  createdAt: string;
}

export interface NewsDraftInput {
  title: string;
  body: string;
  relatedForumId?: string | null;
  coverImageUrl?: string | null;
  /** Si se indica, se programa en vez de publicar ya. */
  scheduledAt?: string | null;
}
