export const NOTICIAS_FORUM_ID = 'noticias';

export const NOTICIAS_RELATED_OPTIONS: { id: string; label: string }[] = [
  { id: 'foro-cofradiero', label: 'Círculo Cofrade' },
  { id: 'pentagrama-cofrade', label: 'Pentagrama Cofrade' },
  { id: 'martillo-trabajadera', label: 'Martillo y Trabajadera' },
  { id: 'hermandades', label: 'Hermandades' },
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
