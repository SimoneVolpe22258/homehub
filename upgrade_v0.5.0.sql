begin;
create table if not exists public.hh_stations(id uuid primary key default gen_random_uuid(),fid uuid not null references public.hh_families on delete cascade,label text not null,secret_hash bytea not null unique,created_at timestamptz not null default now());
alter table public.hh_stations enable row level security;
revoke all on public.hh_stations from public,anon,authenticated;
create or replace function public.hh_station_create(f uuid,n text,s text) returns void language plpgsql security definer set search_path='' as $$ begin if not public.hh_challenge_manager(f) or s !~ '^[0-9a-f]{64}$' or length(trim(n)) not between 1 and 80 then raise exception 'Non autorizzato o dati non validi'; end if; insert into public.hh_stations(fid,label,secret_hash) values(f,trim(n),pg_catalog.sha256(pg_catalog.convert_to(s,'UTF8'))); end $$;
create or replace function public.hh_station_list(f uuid) returns table(id uuid,label text,created_at timestamptz) language sql security definer set search_path='' as $$ select s.id,s.label,s.created_at from public.hh_stations s where s.fid=f and public.hh_challenge_manager(f) $$;
create or replace function public.hh_station_revoke(f uuid,i uuid) returns void language plpgsql security definer set search_path='' as $$ begin if not public.hh_challenge_manager(f) then raise exception 'Non autorizzato'; end if; delete from public.hh_stations where fid=f and id=i; end $$;
create or replace function public.hh_station_access(s text,u uuid,op text,b jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uuid; r jsonb; k text; i uuid; begin
select st.fid into f from public.hh_stations st where st.secret_hash=pg_catalog.sha256(pg_catalog.convert_to(s,'UTF8')) for share;
if not found then raise exception 'Dispositivo non autorizzato'; end if;
if op='members' then return jsonb_build_object('family',(select name from public.hh_families where id=f),'members',coalesce((select jsonb_agg(jsonb_build_object('uid',m.uid,'name',coalesce(nullif(trim(p.name),''),'Familiare '||left(m.uid::text,4)),'avatar',coalesce(nullif(p.avatar,''),'👤'))) from public.hh_memberships m left join public.hh_profiles p on p.uid=m.uid where m.fid=f),'[]'::jsonb)); end if;
if not exists(select 1 from public.hh_memberships m where m.fid=f and m.uid=u) then raise exception 'Familiare non autorizzato'; end if;
if op='read' then return jsonb_build_object('entries',coalesce((select jsonb_agg(to_jsonb(e) order by e.done,e.created_at desc) from public.hh_entries e where e.fid=f),'[]'::jsonb),'plans',coalesce((select jsonb_agg(to_jsonb(p) order by p.due) from public.hh_plans p where p.fid=f),'[]'::jsonb),'challenges',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'uid',c.uid,'title',c.title,'status',c.status,'points',c.points,'bonus',case when c.status='approved' then c.bonus else 0 end)) from public.hh_challenges c where c.fid=f),'[]'::jsonb),'catalog',coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.hh_catalog c where c.fid=f),'[]'::jsonb));
elsif op='entry_add' then k:=b->>'kind'; if k not in ('shopping','board') then raise exception 'Tipo non valido'; end if; insert into public.hh_entries(fid,kind,content,quantity,category,author_id) values(f,k,trim(b->>'title'),left(coalesce(b->>'quantity',''),80),left(coalesce(b->>'category',''),80),u);
elsif op='entry_done' then update public.hh_entries set done=true,completed_at=now(),buyer_id=case when kind='shopping' then u else null end where fid=f and id=(b->>'id')::uuid and not done;
elsif op='plan_add' then insert into public.hh_plans(fid,kind,title,due,author) values(f,'calendar',trim(b->>'title'),(b->>'due')::date,u);
elsif op='task_done' then update public.hh_plans set done=true where fid=f and id=(b->>'id')::uuid and kind='tasks' and (assignee=u or assignee is null);
elsif op='submit' then update public.hh_challenges set status='submitted' where fid=f and id=(b->>'id')::uuid and uid=u and status='assigned';
elsif op='proposal' then insert into public.hh_proposals(fid,uid,kind,title) values(f,u,b->>'kind',trim(b->>'title'));
else raise exception 'Operazione non consentita'; end if; return '{}'::jsonb; end $$;
revoke all on function public.hh_station_create(uuid,text,text),public.hh_station_list(uuid),public.hh_station_revoke(uuid,uuid),public.hh_station_access(text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.hh_station_create(uuid,text,text),public.hh_station_list(uuid),public.hh_station_revoke(uuid,uuid) to authenticated;
grant execute on function public.hh_station_access(text,uuid,text,jsonb) to anon;
commit;
