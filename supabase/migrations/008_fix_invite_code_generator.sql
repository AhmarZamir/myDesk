-- Repair invite-code generation on projects where gen_random_bytes() is unavailable.
-- Uses gen_random_uuid(), which is already available through pgcrypto in this project.

create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1
      from public.desks
      where invite_code = candidate
    );
  end loop;

  return candidate;
end;
$$;

alter table public.desks
  alter column invite_code set default public.generate_invite_code();

update public.desks
set invite_code = public.generate_invite_code()
where invite_code is null;
