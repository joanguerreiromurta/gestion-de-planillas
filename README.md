# Sistema de registro de retiros — Etapa 1

- `app/` — app móvil del chofer (Flutter), funciona sin conexión y sincroniza contra Google Sheets.
- `google-apps-script/` — backend de sincronización y setup de la planilla de Google. Ver su `README.md`.

## Instalar en los celulares de los choferes (sin Google Play)

Como la app no se publica en el Store, se instala directamente el APK:

```
cd app
flutter build apk --release
```

El archivo queda en `app/build/app/outputs/flutter-apk/app-release.apk`.
Se pasa al celular (por cable, WhatsApp, Drive, etc.) y se instala habilitando
"Instalar apps de origen desconocido" la primera vez.

## Primera configuración en cada celular

Al abrir la app por primera vez pide:

1. Nombre del chofer.
2. URL de sincronización (la URL `.../exec` que da Apps Script al publicar el
   backend — ver `google-apps-script/README.md`).

## Desarrollo

```
cd app
flutter pub get
flutter run       # con un celular conectado o un emulador
flutter analyze   # chequeo estático
flutter test      # tests
```
