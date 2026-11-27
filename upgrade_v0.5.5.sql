-- HOME HUB 0.5.5: adulti e amministratori gestiscono Challenge
begin;
create or replace function public.hh_challenge_manager(f uuid) returns boolean language sql security definer set search_path='' as $$ select exists(select 1 from public.hh_memberships m where m.fid=f and m.uid=auth.uid() and m.role in ('admin','adult')) $$;
commit;
