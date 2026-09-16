import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

/** Solo cuentas con profiles.role = admin. */
export const adminGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session() || !auth.canAccess()) {
    return router.createUrlTree(['/login']);
  }
  if (!auth.isAdmin()) {
    return router.createUrlTree(['/app/resumen']);
  }
  return true;
};
