begin;
alter table public.hh_challenges alter column uid drop not null;
alter table public.hh_challenges add column if not exists free_mission boolean not null default false;
alter table public.hh_challenges add column if not exists claim_until date;
create or replace function public.hh_challenge_add(f uuid,u uuid,t text,d date,p integer) returns void language plpgsql security definer set search_path='' as $$ begin if not public.hh_challenge_manager(f) or (u is not null and not exists(select 1 from public.hh_memberships where fid=f and uid=u)) then raise exception 'Non autorizzato'; end if; insert into public.hh_challenges(fid,uid,title,due,points,free_mission,claim_until) values(f,u,trim(t),d,p,u is null,d); end $$;
create or replace function public.hh_mission_move(f uuid,u uuid,i uuid,op text) returns void language plpgsql security definer set search_path='' as $$ begin
if not exists(select 1 from public.hh_memberships where fid=f and uid=u) then raise exception 'Non autorizzato'; end if;
if op='claim' then update public.hh_challenges set uid=u where fid=f and id=i and free_mission and uid is null and status='assigned' and (claim_until is null or claim_until>=current_date);
elsif op='release' then update public.hh_challenges set uid=null where fid=f and id=i and free_mission and uid=u and status='assigned';
else raise exception 'Operazione non consentita'; end if;
if not found then raise exception 'Missione non disponibile'; end if; end $$;
revoke all on function public.hh_mission_move(uuid,uuid,uuid,text) from public,anon,authenticated;
create or replace function public.hh_mission_action(f uuid,i uuid,op text) returns void language plpgsql security definer set search_path='' as $$ begin perform public.hh_mission_move(f,auth.uid(),i,op); end $$;
revoke all on function public.hh_mission_action(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.hh_mission_action(uuid,uuid,text) to authenticated;
create or replace function public.hh_station_access(s text,u uuid,op text,b jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare f uuid; r jsonb; k text; i uuid; begin
select st.fid into f from public.hh_stations st where st.secret_hash=pg_catalog.sha256(pg_catalog.convert_to(s,'UTF8')) for share;
if not found then raise exception 'Dispositivo non autorizzato'; end if;
if op='members' then return jsonb_build_object('family',(select name from public.hh_families where id=f),'members',coalesce((select jsonb_agg(jsonb_build_object('uid',m.uid,'name',coalesce(nullif(trim(p.name),''),'Familiare '||left(m.uid::text,4)),'avatar',coalesce(nullif(p.avatar,''),'👤'))) from public.hh_memberships m left join public.hh_profiles p on p.uid=m.uid where m.fid=f),'[]'::jsonb)); end if;
if not exists(select 1 from public.hh_memberships m where m.fid=f and m.uid=u) then raise exception 'Familiare non autorizzato'; end if;
if op='read' then return jsonb_build_object('entries',coalesce((select jsonb_agg(to_jsonb(e) order by e.done,e.created_at desc) from public.hh_entries e where e.fid=f),'[]'::jsonb),'plans',coalesce((select jsonb_agg(to_jsonb(p) order by p.due) from public.hh_plans p where p.fid=f),'[]'::jsonb),'challenges',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'uid',c.uid,'title',c.title,'status',c.status,'points',c.points,'free_mission',c.free_mission,'due',c.due,'claim_until',c.claim_until,'bonus',case when c.status='approved' then c.bonus else 0 end)) from public.hh_challenges c where c.fid=f),'[]'::jsonb),'catalog',coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.hh_catalog c where c.fid=f),'[]'::jsonb));
elsif op='entry_add' then k:=b->>'kind'; if k not in ('shopping','board') then raise exception 'Tipo non valido'; end if; insert into public.hh_entries(fid,kind,content,quantity,category,author_id) values(f,k,trim(b->>'title'),left(coalesce(b->>'quantity',''),80),left(coalesce(b->>'category',''),80),u);
elsif op='entry_done' then update public.hh_entries set done=true,completed_at=now(),buyer_id=case when kind='shopping' then u else null end where fid=f and id=(b->>'id')::uuid and not done;
elsif op='plan_add' then insert into public.hh_plans(fid,kind,title,due,author) values(f,'calendar',trim(b->>'title'),(b->>'due')::date,u);
elsif op='task_done' then update public.hh_plans set done=true where fid=f and id=(b->>'id')::uuid and kind='tasks' and (assignee=u or assignee is null);
elsif op in ('claim','release') then perform public.hh_mission_move(f,u,(b->>'id')::uuid,op);
elsif op='submit' then update public.hh_challenges set status='submitted' where fid=f and id=(b->>'id')::uuid and uid=u and status='assigned';
elsif op='proposal' then insert into public.hh_proposals(fid,uid,kind,title) values(f,u,b->>'kind',trim(b->>'title'));
else raise exception 'Operazione non consentita'; end if; return '{}'::jsonb; end $$;

commit;
