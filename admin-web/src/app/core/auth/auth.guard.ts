import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

/** Panel Junta (/app): solo staff. Las hermandades van a /hermandad. */
export const authGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (auth.isHermandadAccount() && !auth.canAccess()) {
    return router.createUrlTree(['/hermandad']);
  }
  if (!auth.canAccess()) {
    return router.createUrlTree(['/login'], {
      queryParams: { denied: '1' },
    });
  }
  return true;
};

/** Portal hermandad: cuenta brotherhood (no Junta). */
export const hermandadGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (auth.canAccess()) {
    return router.createUrlTree(['/app/resumen']);
  }
  if (!auth.isHermandadAccount()) {
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

  if (auth.session() && (auth.canAccess() || auth.isHermandadAccount())) {
    return router.createUrlTree([auth.homePath()]);
  }
  return true;
};
