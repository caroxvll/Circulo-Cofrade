import { bootstrapApplication } from '@angular/platform-browser';
import { inject } from '@vercel/analytics';
import { injectSpeedInsights } from '@vercel/speed-insights';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

/** Enlace de recover a veces llega a `/` con tokens; forzar pantalla de cambio. */
const href = window.location.href;
const path = window.location.pathname;
const isRecovery = /[?&#]type=recovery\b/i.test(href);
if (isRecovery && !path.startsWith('/reset-password')) {
  const next = `/reset-password${window.location.search}${window.location.hash}`;
  window.location.replace(next);
} else {
  bootstrapApplication(AppComponent, appConfig)
    .then(() => {
      inject();
      injectSpeedInsights();
    })
    .catch((err) => console.error(err));
}
