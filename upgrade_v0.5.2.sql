begin;
alter table public.hh_challenges drop constraint if exists hh_challenges_status_check;
alter table public.hh_challenges add constraint hh_challenges_status_check check(status in ('assigned','submitted','approved','cancelled'));
alter table public.hh_challenges add column if not exists cancelled_at timestamptz;
alter table public.hh_challenges add column if not exists cancelled_by uuid;
create or replace function public.hh_plan_change(f uuid,i uuid,op text) returns void language plpgsql security definer set search_path='' as $$
declare r public.hh_plans; begin
if not exists(select 1 from public.hh_memberships where fid=f and uid=auth.uid()) then raise exception 'Non autorizzato'; end if;
select * into r from public.hh_plans where fid=f and id=i for update;
if not found then raise exception 'Attività non disponibile'; end if;
if op='toggle' then update public.hh_plans set done=not done where fid=f and id=i;
elsif op='delete' then
if r.kind='tasks' and not public.hh_challenge_manager(f) then raise exception 'Solo i genitori possono eliminare attività'; end if;
delete from public.hh_plans where fid=f and id=i;
else raise exception 'Azione non valida'; end if; end $$;
create or replace function public.hh_challenge_cancel(f uuid,i uuid) returns void language plpgsql security definer set search_path='' as $$
begin
if not public.hh_challenge_manager(f) then raise exception 'Solo i genitori possono annullare missioni'; end if;
update public.hh_challenges set status='cancelled',cancelled_at=now(),cancelled_by=auth.uid() where fid=f and id=i and status<>'cancelled';
if not found then raise exception 'Missione non disponibile'; end if; end $$;
revoke all on function public.hh_challenge_cancel(uuid,uuid) from public,anon,authenticated;
grant execute on function public.hh_challenge_cancel(uuid,uuid) to authenticated;
commit;
