import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

/** Solo cuentas con profiles.role = admin. */
export const adminGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (!auth.isAdmin()) {
    if (auth.isHermandadAccount()) {
      return router.createUrlTree(['/hermandad']);
    }
    await auth.signOut();
    return router.createUrlTree(['/login'], {
      queryParams: { denied: '1' },
    });
  }
  return true;
};
