import { Routes } from '@angular/router';
import { LoginPage } from './auth/login.page';
import { RegisterPage } from './auth/register.page';
import { BusinessChooserPage } from './business/business-chooser.page';
import { authGuard, businessGuard, guestGuard } from './core/guards';
import { HomePage } from './home/home.page';
import { ShellComponent } from './shell/shell.component';

export const routes: Routes = [
  { path: 'entrar', component: LoginPage, canActivate: [guestGuard] },
  { path: 'registro', component: RegisterPage, canActivate: [guestGuard] },
  { path: 'negocios', component: BusinessChooserPage, canActivate: [authGuard] },
  {
    path: '',
    component: ShellComponent,
    canActivate: [businessGuard],
    children: [{ path: '', component: HomePage }],
  },
  { path: '**', redirectTo: '' },
];
