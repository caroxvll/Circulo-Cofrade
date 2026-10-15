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
  /** Color de acento del panel hermandad (#RRGGBB), si lo personalizó. */
  panelAccent: string | null;
}

export function isAdminRole(role: StaffRole | null | undefined): boolean {
  return role === 'admin';
}

/**
 * Acceso al panel web Junta: solo profiles.role = admin.
 * Moderadores/editores operan en la app; no entran al panel web.
 */
export function canAccessJunta(opts: {
  role: StaffRole | null | undefined;
}): boolean {
  return isAdminRole(opts.role);
}

/** Cuenta de hermandad (oficial), verificada o no. */
export function isBrotherhoodAccount(
  accountType: AccountType | null | undefined,
): boolean {
  return accountType === 'brotherhood';
}

/** Acceso al portal privado: hermandad y verificada por la Junta. */
export function canAccessHermandadPortal(opts: {
  accountType: AccountType | null | undefined;
  verified?: boolean;
}): boolean {
  return isBrotherhoodAccount(opts.accountType) && opts.verified === true;
}
