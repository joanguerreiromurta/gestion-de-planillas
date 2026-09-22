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

## Instalar en un iPhone

El proyecto ya tiene la carpeta `app/ios/` con todo lo necesario para compilar
para iOS, pero **Flutter solo puede compilar para iOS desde una Mac** (Apple
no permite compilar/firmar apps iOS en Windows o Linux). Pasos a futuro:

1. Conseguir acceso a una Mac (propia, prestada, o un servicio de Mac en la
   nube como MacStadium/MacinCloud) con [Xcode](https://apps.apple.com/app/xcode/id497799835)
   instalado.
2. Instalar Flutter en esa Mac y clonar este repo (o copiar la carpeta `app/`).
3. Crear una cuenta de [Apple Developer](https://developer.apple.com/) (gratis
   para instalar en tus propios dispositivos por 7 días, o el programa pago de
   USD 99/año para instalaciones sin límite de tiempo y para distribuir a otros
   choferes vía TestFlight).
4. En la Mac, dentro de `app/`:
   ```
   flutter pub get
   open ios/Runner.xcworkspace
   ```
5. En Xcode: seleccionar el proyecto `Runner` → pestaña "Signing & Capabilities"
   → elegir el "Team" de la cuenta de Apple Developer → Xcode genera el
   certificado y el "provisioning profile" automáticamente.
6. Conectar el iPhone por cable, elegirlo como destino en Xcode, y darle Run
   (▶). La primera vez hay que ir en el iPhone a Ajustes → General → VPN y
   gestión de dispositivos → confiar en el certificado de desarrollador.
7. Para no depender de Xcode cada vez (por ejemplo para pasarle la app a otros
   choferes con iPhone), usar **TestFlight**: requiere la cuenta paga de Apple
   Developer, subir un build (`flutter build ipa`) desde Xcode/Transporter a
   App Store Connect, y agregar a los choferes como testers por su email de
   Apple ID.

Sin Mac no hay forma de generar el build de iOS; es una limitación de Apple,
no del proyecto.

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
