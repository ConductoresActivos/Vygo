# VYGO Flutter — versión conectada inicial

Esta versión conserva el diseño de marca y conecta el flujo inicial con el proyecto Supabase.

## Incluye en esta entrega
- Registro con correo/contraseña para pasajero o conductor.
- Inicio y cierre de sesión con Supabase Auth.
- Lectura del perfil y enrutamiento según `profiles.role`.
- Panel de pasajero: crea solicitudes reales, consulta sus viajes y ve las ofertas recibidas.
- Panel de conductor: consulta solicitudes disponibles y registra ofertas.
- Panel admin: consulta métricas básicas, viajes y aprueba/rechaza conductores.
- Configuración de cliente con URL y clave pública/anon.

## Antes de ejecutar
1. Descomprime el ZIP.
2. Abre `lib/config.dart`.
3. Reemplaza `supabaseUrl` con la Project URL de Supabase.
4. Reemplaza `supabaseAnonKey` con la publishable key (o anon key heredada) del proyecto.
5. Nunca uses `service_role` en Flutter.

## SQL adicional obligatorio
En Supabase > SQL Editor, ejecuta el contenido de `supabase/vygo_driver_trips_policy.sql`.
La política inicial permitía que los participantes vieran sus viajes, pero los conductores aprobados también necesitan ver solicitudes aún sin conductor asignado.

## Ejecutar
En una terminal dentro de la carpeta:
```bash
flutter pub get
flutter run
```

## Ajustes de Supabase
- En Authentication > URL Configuration, configura las URLs de redirección si luego habilitas enlaces profundos.
- Para pruebas rápidas puedes desactivar temporalmente la confirmación de correo en Authentication > Providers > Email; para producción es preferible mantener la confirmación activa.
- El registro de conductor crea `driver_profiles` con `verification_status = pending`. El administrador debe aprobarlo.
- El usuario admin ya promovido en la base de datos debe iniciar sesión con el mismo correo y contraseña de su cuenta Supabase.

## Límites conocidos de esta fase
Esta es una primera integración funcional, no una versión lista para publicar en producción. Todavía faltan:
- RPC transaccional para aceptar una oferta y asignar un único conductor (evitar carreras entre ofertas simultáneas).
- Validación estricta de transiciones de estado y cancelaciones en servidor.
- Almacenamiento privado y revisión documental (licencia, identidad, vehículo).
- Mapas, geocodificación, permisos GPS en segundo plano y seguimiento en tiempo real.
- Notificaciones push, pagos, comisiones y soporte.
- Pruebas automatizadas, tratamiento completo de errores y revisión de seguridad.

La pantalla actual de administración permite aprobar conductores y consultar datos; no incluye todavía todas las funciones de administración anunciadas.
