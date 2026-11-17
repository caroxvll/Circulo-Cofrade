import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

/** Panel Junta (/app): solo profiles.role = admin. Hermandades → /hermandad. */
export const authGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (auth.isHermandadAccount() && !auth.isAdmin()) {
    return router.createUrlTree(['/hermandad']);
  }
  if (!auth.isAdmin()) {
    await auth.signOut();
    return router.createUrlTree(['/login'], {
      queryParams: { denied: '1' },
    });
  }
  return true;
};

/** Portal hermandad: brotherhood verificada (admin va al panel Junta). */
export const hermandadGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (auth.isAdmin()) {
    return router.createUrlTree(['/app/resumen']);
  }
  if (!auth.isHermandadAccount()) {
    await auth.signOut();
    return router.createUrlTree(['/login'], {
      queryParams: { denied: '1' },
    });
  }
  return true;
};

export const guestGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return true;
  }

  if (auth.isAdmin() || auth.isHermandadAccount()) {
    return router.createUrlTree([auth.homePath()]);
  }

  // Sesión de cofrade (p. ej. misma de la app): no dejarla colgada en el panel.
  await auth.signOut();
  return true;
};
