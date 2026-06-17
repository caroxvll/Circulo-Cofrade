-- Push desactivado por defecto (opt-in). Ejecutar una vez en SQL Editor.
-- Usuarios que nunca registraron un dispositivo pasan a push_enabled = false.

alter table public.notification_preferences
  alter column push_enabled set default false;

update public.notification_preferences np
set push_enabled = false
where push_enabled = true
  and not exists (
    select 1
    from public.device_tokens dt
    where dt.user_id = np.user_id
  );
