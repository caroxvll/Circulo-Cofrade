export type ConversationTopicStatus =
  | 'published'
  | 'pending'
  | 'rejected'
  | 'all';

export interface ConversationForum {
  id: string;
  name: string;
  description: string;
  topicCount: number;
  messageCount: number;
  isEnabled: boolean;
}

export interface ConversationTopic {
  id: string;
  forumId: string;
  title: string;
  excerpt: string;
  body: string;
  authorHandle: string | null;
  authorId: string | null;
  status: string;
  commentCount: number;
  viewCount: number;
  isClosed: boolean;
  isPinned: boolean;
  isSystem: boolean;
  seasonKey: string | null;
  createdAt: string;
  lastActivityAt: string | null;
}

export interface ConversationReply {
  id: string;
  topicId: string;
  authorId: string | null;
  authorHandle: string | null;
  content: string;
  createdAt: string;
  parentReplyId: string | null;
  deletedAt: string | null;
  deletedBy: string | null;
}
