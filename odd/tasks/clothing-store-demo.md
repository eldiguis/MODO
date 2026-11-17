# Clothing store demo
Objective: Build the MODO clothing-store flow using the supplied visual direction and test Firebase project.
Branch: `codex/firebase-account-cart`; delivery: ask-on-risk, local only; runner: Flutter/Dart.
Baseline: `792931b` — `chore: establish Flutter app baseline`.
Engram mirror: pending because no authoritative runtime session identity is available.

## Specs

S1. Authentication and profile. User requests: "Login funcional"; "Como version de prueba realiza el tema de que los correos y contraseñas se guardan en texto plano"; "Este es el firebase, se debe guardar aqui"; "SI"; and "Ok, ahora necesito que el correo y contraseña se guarden en usuario". Security adaptation: use Firebase Authentication for password credentials; store only UID, name, and email in `usuario/{uid}` and never store passwords in Firestore. Do not read, migrate, or alter the existing plaintext credential documents. Google sign-in remains pending OAuth configuration because the supplied Android config has no OAuth clients. Checks: fake auth/profile repository tests; no real credentials or cloud writes during checks.

S2. Clothing catalog. User requests: "catalogo de ropa (40 prendas)" and "Que todos los productos sean jalados desde firebase". Stream the 40 seeded garments from Firestore collection `productos`, with loading, empty, and error states; keep the curated home selection and full store catalog. Checks: fake repository/widget tests and read-only count verification; no production writes during checks.

S3. Product details. User request: "al presionar una prenda se abre mas detalles y te deja ver sus especificaciones". Tapping any garment opens a detail screen with product image, price, sizes, color, material, fit, care, reviews, and add-to-cart action. Checks: selected garment identity/specification values render and add-to-cart uses that garment.

S4. Camera try-on. User request: "el tema del boton para que se pruebe su ropa elegida mediante acceso a la camara tambien funcional". Provide front and side capture actions using the device camera, a gallery fallback, preview/replacement, and selected garment context. Checks: camera/gallery routes are independently callable through a fake picker; selected garment reaches the try-on flow. Device permission prompts require a physical-device check.

S5. Accessibility and visual consistency. User request: "accesibilidad" and "Utilkiza el diseño que me diste." Preserve the monochrome, minimal style from the supplied PDF-derived design; add semantic labels, screen-reader names, keyboard/focus behavior, readable contrast, and scalable text across login, catalog, detail, cart, and fitting room. Checks: widget semantics and keyboard/focus checks for the modified screens.

S6. Account and accessibility settings. User requests: "Aparte debe haber una seccion donde el usuario vea los ajustes de su ceunta y la accesibilidad." and "en accesibilidad tambn se permita al usuario actualizar su contraseña por otra." Add a dedicated account section reachable from the app navigation, showing the authenticated profile and usable accessibility preferences. Password changes go through Firebase Auth with recent-login handling; password text is never persisted in Firestore. Checks: fake repository/widget coverage for profile, password-change validation, and accessibility controls.

S7. Home hero and green accents. User request: "Que trabaje con esas etiqtetas verdes y esa imagen grande al inicio" with the attached visual reference. Put the large editorial image immediately below the home header, use vivid lime-green accent tags, then show a curated product selection. Checks: web build and visual inspection at a mobile viewport.

S8. Persistent cart and demo checkout. User request: "y que los demas del carrito ... este funcional." Use product IDs from Firestore, support quantity changes/removal, compute totals from the loaded product prices, and persist the authenticated user's cart. Checkout is a demo flow only; it must not charge money. Checks: fake repository tests cover add/update/remove, total, and checkout cart clearing/order creation.

S9. Purchase history and receipt. User request: "un apartado de historial de compras con su boleta este funcional." Persist orders under the authenticated user's profile, show history and a receipt detail for each order. The receipt is clearly marked as a demo comprobante with no tax validity because no payment or SUNAT integration was requested. Checks: fake repository/widget tests verify order snapshot, total, date, and receipt rendering.

S10. Android APK branding. User request: "Genera el apk. Con el nombre de Grupo1 y un logo de una ropa. En la carpeta descargas". Set the Android launcher label to `Grupo1`, replace the default launcher icon with a clothing mark, and deliver `Grupo1.apk` in Downloads. Keep the Android application ID unchanged. Checks: release APK build succeeds and output file/icon resources are present.

S11. Firestore-backed catalog. User reports: "No esta jalando las prendas del firebase, cuando voy a tienda y pongo todo solo me aparecen 4 productos." Replace the hardcoded catalog with a read-only live stream from Firestore `productos`; `Todo` must show every returned product, category filters must filter loaded data, and home may retain a curated maximum of four. Preserve loading, empty, and error states. The existing seeded documents are verified only for `name` and `category`; map optional fields defensively and do not alter Firebase records or rules. Checks: repository/model parsing tests and app analysis/build; no cloud writes.

S12. Screen transitions. User requests: "Ademas que haya una pequeña transicion entre pantallas como un deslizador que se desvanece." Add a brief combined fade/slide animation when switching bottom navigation destinations, respecting the existing Reduce Motion preference. Checks: widget transition test and analyzer.

S13. Nearby stores and product availability. User requests: "Ademas necesito que implementes un geolocalizador (API) para que el cliente pueda ver las tiendas cercanas donde se encuentra cada producto por si quiere ir el mismo a comprar." Clarification: "Si" to using Firebase as the source for store locations and product availability. Assumption to document and implement read-only schema: `tiendas/{storeId}` with `name`, `address`, `location` (Firestore GeoPoint), and optional contact/opening fields; subcollection `inventario/{productId}` with `productId`, `quantity`, and optional store-specific price. Request foreground location only when the shopper opens nearby-store details, compute distances locally, list stores carrying the selected product, and handle denied permissions, disabled location, absent inventory, and no nearby results. Do not invent or seed real store locations; the Firebase collection must be populated and Firestore read rules must permit these reads. Checks: pure distance/sorting and document parsing tests; Android permission declaration; analyzer/build. No background tracking and no location writes.

## Tasks

T1 — S1, inline, pending (Risk: item 2, authentication/security).
T2 — S2-S3, S7, inline, pending (Risk: item 5, Firebase configuration/dependencies).
T3 — S4-S6, inline, pending.
T4 — S8-S9, inline, pending (demo checkout only; no payment processing).
T5 — S10, inline, pending.
T6 — S2, S11, inline, pending (Risk: item 5, Firebase SDK/platform configuration and dependency).
T7 — S13, inline, pending (Risk: item 2, foreground location permission; item 5, geolocation dependency).
T8 — S12, inline, pending (Risk: none; respect existing Reduce Motion behavior).

## Log

L1 — "C:\Users\gabri\Downloads\Proyecto correo\flutter_application_1\nModifica todas las pantallas y agrega las nuevas de la tienda de ropa (Login funcional, catalogo de ropa (40 prendas), al presionar una prenda se abre mas detalles y te deja ver sus especificaciones, el tema del boton para que se pruebe su ropa elegida mediante acceso a la camara tambien funcional y accesibilidad. ) Utilkiza el diseño que me diste."
L2 — "Como version de prueba realiza el tema de que los correos y contraseñas se guardan en texto plano"
L3 — "Este es el firebase, se debe guardar aqui"
L4 — "SI"
L5 — "Aparte debe haber una seccion donde el usuario vea los ajustes de su ceunta y la accesibilidad."
L6 — "Que trabaje con esas etiqtetas verdes y esa imagen grande al inicio"
L7 — "Que todos los productos sean jalados desde firebase"
L8 — "ya te pase el google-services.json que me da firebase. Conectalo"
L9 — "aun no la creo, hay alguna forma de crearlo con un script en vez de estar creando un producto uno por uno?"
L10 — "Ejecutalo tu, tienes acceso completo a la pc. 40 productos"
L11 — "Ok, ahora necesito que el correo y contraseña se guarden en usuario, y en accesibilidad tambn se permita al usuario actualizar su contraseña por otra. Y que los demas del carrito y un apartado de historial de compras con su boleta este funcional."
L12 — "Genera el apk. Con el nombre de Grupo1 y un logo de una ropa. En la carpeta descargas"
L13 — "No esta jalando las prendas del firebase, cuando voy a tienda y pongo todo solo me aparecen 4 productos. Ademas que haya una pequeña transicion entre pantallas como un deslizador que se desvanece. Ademas necesito que implementes un geolocalizador (API) para que el cliente pueda ver las tiendas cercanas donde se encuentra cada producto por si quiere ir el mismo a comprar."
L14 — "Si" (confirmation that store location and availability should come from Firebase)
Evidence — Firebase config identifies Android app project `huillcamezaedgardgabriel`; no Firebase options, Firestore rules, or OAuth clients were found in the project. Do not seed/write cloud records during local checks. Google OAuth/web Firebase setup is a known dependency.
Implementation — Added a fifth `Cuenta` navigation destination with profile name, account information summary, and functional `Texto grande`, `Alto contraste`, and `Reducir movimiento` controls. Updated `MediaQuery` and `Theme` in the shop shell so the accessibility preferences affect the in-app screens. `flutter analyze` passed and `flutter build web --release` passed. Widget test execution is unavailable: VM tests cannot compile the existing web-only Google Sign-In import; Chrome tests could not locate Chrome, and pointing the runner at Edge did not complete. A debug Edge session was launched on port 7358 for manual preview.
Visual refinement — Replaced the neutral accent with vivid lime green, moved the existing editorial hero directly under the home header, and changed the home grid to a four-item weekly selection while preserving the full catalog entry point. `flutter analyze` passed and `flutter build web --release` passed. Browser screenshot inspection remains unavailable in this turn.
Firebase seed — After explicit user authorization, created 40 demo documents in Firestore project `huillcamezaedgardgabriel`, collection `productos`, using deterministic `demo_*` IDs. A readback verified all 40 documents and required `name`/`category` fields. The Flutter app has not yet been changed to read this collection; Firebase client setup and app integration remain pending.
Security note — A previously shared screenshot showed plaintext password data. Do not repeat, read, migrate, or use those credentials. Recommend changing the exposed password and removing the plaintext field manually; do not delete or rewrite existing documents without explicit authorization.
Baseline — Initialized a project-local Git repository on `codex/firebase-account-cart` after user approval. The staged snapshot contained no Firebase/service-account credential files; `android/local.properties` remains ignored. Root baseline commit: `792931b`.
