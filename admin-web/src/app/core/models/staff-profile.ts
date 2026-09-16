export type StaffRole = 'member' | 'editor' | 'moderator' | 'admin';

export interface StaffProfile {
  id: string;
  handle: string | null;
  displayName: string | null;
  role: StaffRole;
  avatarUrl: string | null;
}

export function isAdminRole(role: StaffRole | null | undefined): boolean {
  return role === 'admin';
}

/** Acceso al panel: admin, rol staff o moderador de foro. */
export function canAccessJunta(opts: {
  role: StaffRole | null | undefined;
  moderatedForumCount: number;
}): boolean {
  if (opts.role === 'admin' || opts.role === 'moderator' || opts.role === 'editor') {
    return true;
  }
  return opts.moderatedForumCount > 0;
}
