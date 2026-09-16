import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.init();

  if (!auth.session()) {
    return router.createUrlTree(['/login']);
  }
  if (!auth.canAccess()) {
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

  if (auth.session() && auth.canAccess()) {
    return router.createUrlTree(['/app/resumen']);
  }
  return true;
};
