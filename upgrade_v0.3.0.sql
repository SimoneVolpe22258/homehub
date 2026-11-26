begin;
alter table public.hh_entries add column if not exists quantity text not null default '', add column if not exists category text not null default '', add column if not exists priority text not null default 'normale', add column if not exists due_date date, add column if not exists author_id uuid references auth.users(id) on delete set null, add column if not exists completed_at timestamptz;
create or replace function public.hh_entry_add_v3(f uuid,k text,c text,q text,cat text,p text,d date) returns void language plpgsql security definer set search_path='' as $$ begin
if not exists(select 1 from public.hh_memberships m where m.fid=f and m.uid=auth.uid()) then raise exception 'Non autorizzato'; end if;
if length(q)>80 or length(cat)>80 or p not in ('normale','alta','bassa') then raise exception 'Dati non validi'; end if;
insert into public.hh_entries(fid,kind,content,quantity,category,priority,due_date,author_id) values(f,k,trim(c),q,cat,p,d,auth.uid()); end $$;
create or replace function public.hh_entry_change(f uuid,i uuid,action text) returns void language plpgsql security definer set search_path='' as $$ begin if not exists(select 1 from public.hh_memberships m where m.fid=f and m.uid=auth.uid()) then raise exception 'Non autorizzato'; end if; if action='toggle' then update public.hh_entries set done=not done,completed_at=case when done then null else now() end where fid=f and id=i; elsif action='delete' then delete from public.hh_entries where fid=f and id=i; else raise exception 'Azione non valida'; end if; end $$;
revoke all on function public.hh_entry_add_v3(uuid,text,text,text,text,text,date) from public,anon;
grant execute on function public.hh_entry_add_v3(uuid,text,text,text,text,text,date) to authenticated;
commit;
