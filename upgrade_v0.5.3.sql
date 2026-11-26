begin;
alter table public.hh_plans add column if not exists cancelled_at timestamptz, add column if not exists completed_at timestamptz, add column if not exists finished_by uuid, add column if not exists created_at timestamptz;
alter table public.hh_plans alter column created_at set default now();
create or replace function public.hh_plan_change(f uuid,i uuid,op text) returns void language plpgsql security definer set search_path='' as $$
declare r public.hh_plans; begin
if not exists(select 1 from public.hh_memberships where fid=f and uid=auth.uid()) then raise exception 'Non autorizzato'; end if;
select * into r from public.hh_plans where fid=f and id=i for update;
if not found then raise exception 'Attività non disponibile'; end if;
if r.kind='tasks' then
 if r.cancelled_at is not null then raise exception 'Attività annullata'; end if;
 if op='delete' and public.hh_challenge_manager(f) then update public.hh_plans set cancelled_at=now(),finished_by=auth.uid() where id=i;
 elsif op='toggle' and (not r.done or public.hh_challenge_manager(f)) then update public.hh_plans set done=not done,completed_at=case when done then null else now() end,finished_by=auth.uid() where id=i;
 else raise exception 'Operazione non consentita'; end if;
elsif op='toggle' then update public.hh_plans set done=not done where id=i;
elsif op='delete' then delete from public.hh_plans where id=i;
else raise exception 'Azione non valida'; end if; end $$;
create table public.hh_point_changes(id uuid primary key default gen_random_uuid(),fid uuid not null references public.hh_families on delete cascade,uid uuid not null,delta integer not null check(delta between -100000 and 100000 and delta<>0),reason text not null check(length(trim(reason)) between 1 and 500),author uuid not null,created_at timestamptz not null default now(),reversed_at timestamptz,reversed_by uuid);
create table public.hh_goals(id uuid primary key default gen_random_uuid(),fid uuid not null references public.hh_families on delete cascade,uid uuid not null,title text not null check(length(trim(title)) between 1 and 200),threshold integer not null check(threshold>0),consume boolean not null default false,created_at timestamptz not null default now(),delivered_at timestamptz);
alter table public.hh_point_changes enable row level security;
alter table public.hh_goals enable row level security;
revoke all on public.hh_point_changes,public.hh_goals from public,anon,authenticated;
create function public.hh_rewards(f uuid) returns jsonb language sql security definer set search_path='' as $$ select case when exists(select 1 from public.hh_memberships where fid=f and uid=auth.uid()) then jsonb_build_object('changes',coalesce((select jsonb_agg(to_jsonb(c) order by created_at desc) from public.hh_point_changes c where fid=f),'[]'::jsonb),'goals',coalesce((select jsonb_agg(to_jsonb(g) order by created_at desc) from public.hh_goals g where fid=f),'[]'::jsonb)) end $$;
create function public.hh_reward_change(f uuid,op text,u uuid default null,i uuid default null,t text default '',p integer default 0,c boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare g public.hh_goals; score bigint; begin
if not public.hh_challenge_manager(f) then raise exception 'Solo i genitori'; end if;
perform pg_advisory_xact_lock(hashtextextended(f::text,0));
if op in ('points','goal') and not exists(select 1 from public.hh_memberships where fid=f and uid=u) then raise exception 'Familiare non valido'; end if;
if op='points' then insert into public.hh_point_changes(fid,uid,delta,reason,author) values(f,u,p,trim(t),auth.uid());
elsif op='reverse' then update public.hh_point_changes set reversed_at=now(),reversed_by=auth.uid() where fid=f and id=i and reversed_at is null;
elsif op='goal' then insert into public.hh_goals(fid,uid,title,threshold,consume) values(f,u,trim(t),p,c);
elsif op='deliver' then select * into g from public.hh_goals where fid=f and id=i and delivered_at is null for update; if not found then raise exception 'Premio non disponibile'; end if;
select coalesce((select sum(points+bonus) from public.hh_challenges where fid=f and uid=g.uid and status='approved'),0)+coalesce((select sum(delta) from public.hh_point_changes where fid=f and uid=g.uid and reversed_at is null),0)-coalesce((select sum(threshold) from public.hh_goals where fid=f and uid=g.uid and consume and delivered_at is not null),0) into score;
if score<g.threshold then raise exception 'Punti insufficienti'; end if;
update public.hh_goals set delivered_at=now() where id=i;
else raise exception 'Azione non valida'; end if; end $$;
create function public.hh_activity_edit(f uuid,i uuid,k text,t text,d date,p integer default 0) returns void language plpgsql security definer set search_path='' as $$ begin
if not public.hh_challenge_manager(f) then raise exception 'Solo i genitori'; end if;
if k='tasks' then update public.hh_plans set title=trim(t),due=d where fid=f and id=i and kind='tasks' and not done and cancelled_at is null;
elsif k='challenge' then update public.hh_challenges set title=trim(t),due=d,points=p where fid=f and id=i and status='assigned'; else raise exception 'Tipo non valido'; end if;
if not found then raise exception 'Attività non modificabile'; end if; end $$;
revoke all on function public.hh_rewards(uuid),public.hh_reward_change(uuid,text,uuid,uuid,text,integer,boolean),public.hh_activity_edit(uuid,uuid,text,text,date,integer) from public,anon;
grant execute on function public.hh_rewards(uuid),public.hh_reward_change(uuid,text,uuid,uuid,text,integer,boolean),public.hh_activity_edit(uuid,uuid,text,text,date,integer) to authenticated;
create function public.hh_plan_history_guard() returns trigger language plpgsql set search_path='' as $$ begin
if old.cancelled_at is not null and new.done is distinct from old.done then raise exception 'Attività annullata'; end if;
if new.done and not old.done and new.completed_at is null then new.completed_at=now(); end if;
return new; end $$;
create trigger hh_plan_history_guard before update on public.hh_plans for each row execute function public.hh_plan_history_guard();
commit;
