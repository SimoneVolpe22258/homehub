begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('hh-photos','hh-photos',false,524288,array['image/jpeg']) on conflict(id) do nothing;
alter table public.hh_proposals add column if not exists reviewed_at timestamptz;
create function public.hh_photo_review_stamp() returns trigger language plpgsql set search_path='' as $$ begin if old.status='pending' and new.status<>'pending' then new.reviewed_at=now(); end if; return new; end $$;
create trigger hh_photo_review_stamp before update on public.hh_proposals for each row execute function public.hh_photo_review_stamp();
create function public.hh_photo_access(path text, writing boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare a text[]:=string_to_array(path,'/'); f uuid; i uuid; owner_id uuid; active boolean; manager boolean; begin
if array_length(a,1)<>4 or a[4] !~ '^[1-3]\.jpg$' then return false; end if;
f:=a[1]::uuid; i:=a[3]::uuid;
if not exists(select 1 from public.hh_memberships where fid=f and uid=auth.uid()) then return false; end if;
manager:=public.hh_challenge_manager(f);
case a[2]
when 'tasks' then select coalesce(assignee,author),not done and cancelled_at is null into owner_id,active from public.hh_plans where fid=f and id=i and kind='tasks';
when 'challenge' then select uid,status in ('assigned','submitted') into owner_id,active from public.hh_challenges where fid=f and id=i;
when 'points' then select uid,true into owner_id,active from public.hh_point_changes where fid=f and id=i and created_at>now()-interval '30 days';
when 'proposal' then select uid,status='pending' into owner_id,active from public.hh_proposals where fid=f and id=i;
else return false; end case;
if not found then return false; end if;
if a[2] in ('points','proposal') and not (manager or owner_id=auth.uid()) then return false; end if;
return coalesce(not writing or (active and (manager or (a[2]<>'points' and owner_id=auth.uid()))),false);
exception when invalid_text_representation then return false; end $$;
revoke all on function public.hh_photo_access(text,boolean) from public,anon;
grant execute on function public.hh_photo_access(text,boolean) to authenticated;
create policy hh_photo_read on storage.objects for select to authenticated using(bucket_id='hh-photos' and public.hh_photo_access(name,false));
create policy hh_photo_insert on storage.objects for insert to authenticated with check(bucket_id='hh-photos' and public.hh_photo_access(name,true));
create function public.hh_photo_expired() returns table(path text) language sql security definer set search_path='' as $$
select o.name from storage.objects o where o.bucket_id='hh-photos' and case split_part(o.name,'/',2)
when 'tasks' then exists(select 1 from public.hh_plans p where p.id::text=split_part(o.name,'/',3) and coalesce(p.cancelled_at,p.completed_at)<now()-interval '30 days' and (p.done or p.cancelled_at is not null))
when 'challenge' then exists(select 1 from public.hh_challenges p where p.id::text=split_part(o.name,'/',3) and p.status in ('approved','cancelled') and coalesce(p.cancelled_at,p.approved_at)<now()-interval '30 days')
when 'points' then exists(select 1 from public.hh_point_changes p where p.id::text=split_part(o.name,'/',3) and p.created_at<now()-interval '30 days')
when 'proposal' then exists(select 1 from public.hh_proposals p where p.id::text=split_part(o.name,'/',3) and p.reviewed_at<now()-interval '30 days') else false end limit 500 $$;
revoke all on function public.hh_photo_expired() from public,anon,authenticated;
grant execute on function public.hh_photo_expired() to service_role;
commit;
