export type StaffRole = 'member' | 'editor' | 'moderator' | 'admin';

export type AccountType = 'cofrade' | 'brotherhood' | string;

export interface StaffProfile {
  id: string;
  handle: string | null;
  displayName: string | null;
  role: StaffRole;
  avatarUrl: string | null;
  accountType: AccountType;
  verified: boolean;
}

export function isAdminRole(role: StaffRole | null | undefined): boolean {
  return role === 'admin';
}

/** Acceso al panel Junta: admin, rol staff o moderador de foro. */
export function canAccessJunta(opts: {
  role: StaffRole | null | undefined;
  moderatedForumCount: number;
}): boolean {
  if (opts.role === 'admin' || opts.role === 'moderator' || opts.role === 'editor') {
    return true;
  }
  return opts.moderatedForumCount > 0;
}

/** Acceso al portal privado de hermandad. */
export function canAccessHermandadPortal(opts: {
  accountType: AccountType | null | undefined;
  verified?: boolean;
}): boolean {
  return opts.accountType === 'brotherhood';
}
