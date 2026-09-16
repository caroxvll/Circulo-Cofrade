export interface ModerationTopic {
  id: string;
  forumId: string;
  title: string;
  excerpt: string;
  authorHandle: string | null;
  coverImageUrl: string | null;
  createdAt: string;
  rejectionReason: string | null;
  rejectedAt: string | null;
}

export interface PendingEvent {
  id: string;
  title: string;
  subtitle: string | null;
  eventType: string | null;
  startsAt: string;
  createdByHandle: string | null;
  createdAt: string;
}

export interface ModerationReportItem {
  id: string;
  targetType: 'profile' | 'topic' | 'reply' | string;
  targetId: string;
  reason: string;
  details: string;
  createdAt: string;
  reporterHandle: string | null;
  targetLabel: string;
  targetForumId: string | null;
  authorProfileId: string | null;
}

export interface ModerationReportGroup {
  targetType: string;
  targetId: string;
  targetLabel: string;
  targetForumId: string | null;
  authorProfileId: string | null;
  reasonsSummary: string;
  latestAt: string;
  reports: ModerationReportItem[];
}

export interface QueueCounts {
  topics: number;
  reports: number;
  events: number;
  closeRequests: number;
}

export const REJECTION_PRESETS = [
  'Ya existe un tema igual o muy similar',
  'Fuera de tema para este foro',
  'Contenido inadecuado o irrespetuoso',
  'Falta información para poder publicarlo',
] as const;
