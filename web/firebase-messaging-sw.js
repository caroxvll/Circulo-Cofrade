importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

// Claves públicas del proyecto Circulo Cofrade (web).
firebase.initializeApp({
  apiKey: 'AIzaSyDankoBb8Sba0jl46dXSeR8BSDDf1-Pu7U',
  authDomain: 'circulo-cofrade.firebaseapp.com',
  projectId: 'circulo-cofrade',
  storageBucket: 'circulo-cofrade.firebasestorage.app',
  messagingSenderId: '869645479538',
  appId: '1:869645479538:web:fdfa0616b1940eb438dceb',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title =
    payload.notification?.title || payload.data?.title || 'Círculo Cofrade';
  const body = payload.notification?.body || payload.data?.body || '';

  return self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});
