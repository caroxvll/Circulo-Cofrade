import { Routes } from '@angular/router';
import { adminGuard } from './core/auth/admin.guard';
import { authGuard, guestGuard, hermandadGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'app/resumen' },
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () =>
      import('./pages/login/login.component').then((m) => m.LoginComponent),
  },
  {
    path: 'hermandad',
    canActivate: [hermandadGuard],
    loadComponent: () =>
      import('./layout/hermandad-shell.component').then(
        (m) => m.HermandadShellComponent,
      ),
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./pages/hermandad-portal/home/hermandad-home.component').then(
            (m) => m.HermandadHomePageComponent,
          ),
      },
      {
        path: 'publicar',
        loadComponent: () =>
          import(
            './pages/hermandad-portal/publish/hermandad-publish.component'
          ).then((m) => m.HermandadPublishPageComponent),
      },
      {
        path: 'publicaciones',
        loadComponent: () =>
          import(
            './pages/hermandad-portal/posts/hermandad-posts.component'
          ).then((m) => m.HermandadPostsPageComponent),
      },
    ],
  },
  {
    path: 'app',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./layout/shell.component').then((m) => m.ShellComponent),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'resumen' },
      {
        path: 'resumen',
        loadComponent: () =>
          import('./pages/overview/overview.component').then(
            (m) => m.OverviewComponent,
          ),
      },
      {
        path: 'temas',
        loadComponent: () =>
          import('./pages/topics/topics.component').then(
            (m) => m.TopicsPageComponent,
          ),
      },
      {
        path: 'rechazos',
        loadComponent: () =>
          import('./pages/rejected-topics/rejected-topics.component').then(
            (m) => m.RejectedTopicsPageComponent,
          ),
      },
      {
        path: 'reportes',
        loadComponent: () =>
          import('./pages/reports/reports.component').then(
            (m) => m.ReportsPageComponent,
          ),
      },
      {
        path: 'eventos',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/events/events.component').then(
            (m) => m.EventsPageComponent,
          ),
      },
      {
        path: 'cierres',
        loadComponent: () =>
          import('./pages/close-requests/close-requests.component').then(
            (m) => m.CloseRequestsPageComponent,
          ),
      },
      {
        path: 'conversaciones',
        loadComponent: () =>
          import('./pages/conversations/conversations.component').then(
            (m) => m.ConversationsPageComponent,
          ),
      },
      {
        path: 'noticias',
        loadComponent: () =>
          import('./pages/news/news.component').then((m) => m.NewsPageComponent),
      },
      {
        path: 'usuarios',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/users/users.component').then(
            (m) => m.UsersPageComponent,
          ),
      },
      {
        path: 'moderadores',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/moderators/moderators.component').then(
            (m) => m.ModeratorsPageComponent,
          ),
      },
      {
        path: 'hermandades',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/hermandades/hermandades.component').then(
            (m) => m.HermandadesPageComponent,
          ),
      },
      {
        path: 'foros',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/forums/forums.component').then(
            (m) => m.ForumsPageComponent,
          ),
      },
      {
        path: 'temporada',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/season/season.component').then(
            (m) => m.SeasonPageComponent,
          ),
      },
      {
        path: 'patrocinios',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/ads/ads.component').then((m) => m.AdsPageComponent),
      },
      {
        path: 'empresas',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/companies/companies.component').then(
            (m) => m.CompaniesPageComponent,
          ),
      },
      {
        path: 'finanzas',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/finance/finance.component').then(
            (m) => m.FinancePageComponent,
          ),
      },
      {
        path: 'quiz',
        loadComponent: () =>
          import('./pages/quiz/quiz.component').then((m) => m.QuizPageComponent),
      },
      {
        path: 'notificaciones',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/notifications/notifications.component').then(
            (m) => m.NotificationsPageComponent,
          ),
      },
      {
        path: 'simulacion',
        canActivate: [adminGuard],
        loadComponent: () =>
          import('./pages/demo-world/demo-world.component').then(
            (m) => m.DemoWorldPageComponent,
          ),
      },
    ],
  },
  { path: '**', redirectTo: 'app/resumen' },
];
