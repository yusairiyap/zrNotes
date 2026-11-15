-- zrNotes initial schema. Every row belongs to one user and RLS limits access to the owner.

create table public.folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  parent_id uuid references public.folders(id) on delete cascade,
  name text not null default 'New folder',
  sort_order double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  folder_id uuid references public.folders(id) on delete set null,
  parent_note_id uuid references public.notes(id) on delete cascade,
  title text not null default 'Untitled',
  description text not null default '',
  color bigint,
  icon text,
  pinned boolean not null default false,
  sort_order double precision not null default 0,
  map_x double precision,
  map_y double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  note_id uuid not null references public.notes(id) on delete cascade,
  title text not null default '',
  header_kind text not null default 'none' check (header_kind in ('none','icon','emoji','image')),
  header_value text,
  color bigint,
  x double precision not null default 0,
  y double precision not null default 0,
  width double precision not null default 360,
  z_index integer not null default 0,
  content jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index folders_user_idx on public.folders(user_id);
create index folders_parent_idx on public.folders(parent_id);
create index notes_user_idx on public.notes(user_id);
create index notes_folder_idx on public.notes(folder_id);
create index notes_parent_idx on public.notes(parent_note_id);
create index sections_user_idx on public.sections(user_id);
create index sections_note_idx on public.sections(note_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger folders_updated before update on public.folders for each row execute function public.set_updated_at();
create trigger notes_updated before update on public.notes for each row execute function public.set_updated_at();
create trigger sections_updated before update on public.sections for each row execute function public.set_updated_at();
create trigger user_settings_updated before update on public.user_settings for each row execute function public.set_updated_at();

alter table public.folders enable row level security;
alter table public.notes enable row level security;
alter table public.sections enable row level security;
alter table public.user_settings enable row level security;

create policy "owner all" on public.folders for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner all" on public.notes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner all" on public.sections for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "owner all" on public.user_settings for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Images dropped into notes. Files live under <user id>/<random uuid>.<ext>.
-- The bucket is public so an image URL keeps working inside a note, but only the owner can upload or delete.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('note-images', 'note-images', true, 10485760, array['image/png','image/jpeg','image/gif','image/webp'])
on conflict (id) do nothing;

create policy "note images insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'note-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "note images update own" on storage.objects for update to authenticated
  using (bucket_id = 'note-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "note images delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'note-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
