# VYGO — Flutter + Supabase

**MUÉVETE A TU MANERA.**

Esta carpeta contiene una estructura Flutter corregida para una sola app Android con dos modalidades (pasajero y conductor) y una ruta de administración basada en el rol guardado en Supabase.

## Estructura

- `lib/main.dart`: aplicación Flutter.
- `lib/config.dart`: URL y clave pública (publishable) de Supabase.
- `pubspec.yaml`: dependencias.
- `.github/workflows/build-android.yml`: genera el APK en GitHub Actions.

## Importante sobre Supabase

- La URL y la clave `sb_publishable_...` son datos de cliente. La clave publishable está diseñada para usarse en la app; nunca agregues una `service_role` o `secret` key.
- El registro depende del trigger `vygo_on_auth_user_created` y de las políticas RLS de tu proyecto.
- No vuelvas a ejecutar el esquema inicial: las tablas ya existen.
- El SQL de esquema original se conserva en `docs/` solo como referencia, no es una migración para ejecutar.
- La app actual incluye autenticación por correo/contraseña, selección de modalidad al registrarse, solicitud de viajes, ofertas de conductores y panel básico de aprobación. El servidor debe proteger todos los datos mediante RLS.

## Subir a GitHub

Sube el CONTENIDO de esta carpeta a la raíz del repositorio, manteniendo las carpetas `lib/` y `.github/`.

Antes o después de subir:
1. Elimina los archivos antiguos `main.dart` y `config.dart` que estén en la raíz del repositorio. No elimines `pubspec.yaml`.
2. Asegúrate de que `lib/main.dart` y `lib/config.dart` queden dentro de `lib/`.
3. Conserva `pubspec.yaml` en la raíz.
4. No subas archivos con claves `service_role` o `secret`.

## Generar APK

En GitHub:
1. Abre la pestaña **Actions** del repositorio.
2. Selecciona **Build VYGO Android APK**.
3. Pulsa **Run workflow**.
4. Cuando termine correctamente, abre la ejecución y descarga el artefacto `vygo-android-release`.

El workflow crea la carpeta Android si aún no existe, descarga dependencias y compila el APK.

## Funciones aún no incluidas

Esta versión no incluye todavía mapas/GPS en vivo, notificaciones push, pagos, ni aceptación atómica de ofertas en el servidor. La aceptación de ofertas y los cambios de estado deben implementarse con funciones seguras del backend antes de producción.
