# Front para un negocio nuevo

El código no trae datos de ningún negocio: nombre, URL del backend, contacto y avisos salen de `negocio.env`.

1. Copia `negocio.env.example` a `negocio.env` y rellénalo (`APP_NAME` y `BACKEND_URL` son obligatorios).
2. Reemplaza el logo: `assets/images/logo_app.png` y `assets/images/logo_cuadrado.png` (y los íconos de `web/icons/` y `web/favicon.png`).
3. Compila con `bash tool/build_web.sh`. Para un staging: `bash tool/build_web.sh --dart-define=BACKEND_URL=https://staging.ejemplo.co`.
4. Crea el proyecto de Firebase Hosting del negocio y apunta `projectId` y el secret del workflow `firebase-hosting-merge.yml` a él.
5. En el backend del negocio, `WEBSOCKET_ALLOWED_ORIGINS` debe incluir la URL donde publiques este front (si no, el navegador bloquea todo por CORS).
6. Los textos legales (`lib/utils/legal_texts.dart`) se arman con los datos de `negocio.env`; el contenido lo revisa un abogado.

Lo que sigue fuera de la plantilla: el nombre interno del paquete Dart (`vercy_motos` en `pubspec.yaml`) y los ejemplos de `docs/prd`; no se ven en la aplicación. Las apps Android/iOS/escritorio usan «Mi Negocio» como nombre: cámbialo en cada plataforma si se publican.
