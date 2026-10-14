import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { SessionService } from './session.service';

/// Solo con sesión iniciada; si no, a la pantalla de entrada.
export const authGuard: CanActivateFn = () => {
  const session = inject(SessionService);
  return session.isSignedIn() ? true : inject(Router).createUrlTree(['/entrar']);
};

/// Solo sin sesión (entrar y registrarse); con sesión, a la raíz.
export const guestGuard: CanActivateFn = () => {
  const session = inject(SessionService);
  return session.isSignedIn() ? inject(Router).createUrlTree(['/']) : true;
};

/// Con sesión y un negocio activo que siga siendo del usuario; si no, a elegir negocio. Al
/// recargar la página los negocios se vuelven a pedir al servidor.
export const businessGuard: CanActivateFn = async () => {
  const session = inject(SessionService);
  const router = inject(Router);
  if (!session.isSignedIn()) return router.createUrlTree(['/entrar']);
  if (!session.activeBusinessId()) return router.createUrlTree(['/negocios']);
  try {
    if (session.businesses() === null) await session.loadBusinesses();
  } catch {
    // Si no se puede comprobar, la pantalla mostrará el error al pedir sus datos.
    return true;
  }
  if (!session.activeBusiness()) {
    session.selectBusiness(null);
    return router.createUrlTree(['/negocios']);
  }
  return true;
};
