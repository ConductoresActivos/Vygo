-- VYGO | Parche de lectura de solicitudes para conductores aprobados
-- Ejecutar DESPUÉS de la migración inicial en Supabase > SQL Editor.
-- Permite que un conductor aprobado vea solicitudes aún no asignadas.

drop policy if exists "trips_select_members_admin" on public.trips;

create policy "trips_select_members_admin"
on public.trips
for select
to authenticated
using (
  passenger_id = (select auth.uid())
  or driver_id = (select auth.uid())
  or (select public.vygo_is_admin())
  or (
    driver_id is null
    and status in ('requested', 'negotiating')
    and exists (
      select 1
      from public.driver_profiles d
      where d.user_id = (select auth.uid())
        and d.verification_status = 'approved'
    )
  )
);

-- El panel necesita leer perfiles de conductores pendientes; el admin
-- ya tiene acceso mediante la política driver_profiles_select existente.
