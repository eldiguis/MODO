# Configuración de Google OAuth y Huellas SHA-256 en Firebase

Este documento detalla la configuración técnica para habilitar **Google Sign-In** tanto en la aplicación Android (Flutter) como en el panel web administrativo (desplegado en Vercel) para el proyecto Firebase `huillcamezaedgardgabriel`.

---

## 1. Huellas Digitales del Certificado (Keystore)

Para que Android permita autenticar usuarios con Google a través de Firebase, es **obligatorio** registrar las huellas digitales SHA-1 y SHA-256 en Firebase Console.

### Huellas Extraídas del Entorno Local (Debug Keystore)
Keystore: `~/.android/debug.keystore` (Alias: `androiddebugkey`)

* **SHA-1 (Debug)**:
  ```text
  58:EA:76:A0:96:13:01:EC:A5:49:18:A7:FF:2B:88:22:E2:AD:36:A5
  ```
* **SHA-256 (Debug)**:
  ```text
  53:AE:9F:DC:2A:9F:F9:70:74:C5:E7:F9:F0:62:71:2B:8A:90:8F:5A:B5:39:A1:76:F9:D2:89:E3:F7:7F:A4:79
  ```

> [!NOTE]
> Para volver a consultar estas huellas en cualquier momento desde la terminal:
> ```bash
> keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
> ```

---

## 2. Registro en Firebase Console (Paso a Paso para Android)

1. Ingresa a [Firebase Console](https://console.firebase.google.com/) y selecciona el proyecto **`huillcamezaedgardgabriel`**.
2. Dirígete a **Project Settings (Configuración del proyecto)** haciendo clic en el engranaje ⚙️ junto a *Project Overview*.
3. En la pestaña **General**, desplázate hacia abajo hasta la sección **Tus apps**.
4. Selecciona tu app Android (`com.example.flutter_application_1`).
5. En la sección **Huellas digitales de certificados SHA**, haz clic en **Agregar huella digital**:
   - Pega primero el **SHA-1** y guarda.
   - Haz clic nuevamente en **Agregar huella digital**, pega el **SHA-256** y guarda.
6. **Descargar el nuevo `google-services.json`**:
   - Una vez agregadas las huellas, Firebase regenerará automáticamente los clientes OAuth 2.0.
   - Haz clic en el botón azul **Descargar google-services.json**.
   - Coloca este archivo descargado en la ruta del proyecto:
     ```text
     android/app/google-services.json
     ```
   *(Nota: Si `"oauth_client"` estaba vacío en el archivo anterior, con este paso aparecerán los Client IDs creados para Android y Web).*

---

## 3. Habilitación de Google Sign-In en Firebase Authentication

1. En el menú lateral izquierdo de Firebase Console, ve a **Build -> Authentication**.
2. Selecciona la pestaña **Sign-in method**.
3. En la lista de proveedores, selecciona **Google**.
4. Activa el interruptor **Habilitar**.
5. Selecciona el **Correo electrónico de asistencia para el proyecto** (tu correo de Google).
6. Haz clic en **Guardar**.

---

## 4. Configuración para el Portal Web y Despliegue en Vercel

> [!IMPORTANT]
> **Diferencia Técnica Clave**: La plataforma Web **NO** utiliza huellas SHA-256 (las huellas SHA pertenecen exclusivamente a certificados de firma de binarios Android/Keystore).
> Para la Web, Firebase Authentication protege el acceso mediante **Dominios Autorizados (Authorized Domains)**.

1. En **Authentication -> Settings -> Dominios autorizados**:
2. Verifica que estén presentes:
   - `localhost`
   - `127.0.0.1`
   - `huillcamezaedgardgabriel.firebaseapp.com`
   - `huillcamezaedgardgabriel.web.app`
3. Haz clic en **Agregar dominio** e ingresa los dominios donde desplegarás la web:
   - `modoweb-flame.vercel.app`
   - Tu subdominio de Vercel (por ejemplo `tu-proyecto.vercel.app`).
4. Con esto, `firebase.auth().signInWithPopup(new firebase.auth.GoogleAuthProvider())` funcionará sin bloqueos CORS ni errores `auth/unauthorized-domain`.

---

## 5. Keystore de Producción (Release APK)

Si vas a compilar el APK de producción (ej. `flutter build apk --release` o `Grupo1.apk`):
1. Si generas un keystore propio para producción:
   ```bash
   keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias modo_key
   ```
2. Extrae sus huellas:
   ```bash
   keytool -list -v -keystore release.jks -alias modo_key
   ```
3. Agrega las huellas SHA-1 y SHA-256 resultantes en Firebase Console siguiendo los mismos pasos del apartado 2.
