-- Icons for folders, and checklist progress on notes so the navigation can show "3/5" without loading every section.
alter table public.folders add column icon text;
alter table public.notes add column todo_total integer not null default 0;
alter table public.notes add column todo_done integer not null default 0;
