create extension if not exists "pgcrypto";

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists desks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'custom',
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists desk_members (
  desk_id uuid not null references desks(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member','viewer')),
  joined_at timestamptz not null default now(),
  primary key (desk_id, user_id)
);

create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  desk_id uuid references desks(id) on delete cascade,
  title text not null,
  category text not null default 'other',
  storage_path text not null,
  visibility text not null default 'private' check (visibility in ('private','desk','custom')),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists bills (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  desk_id uuid references desks(id) on delete cascade,
  title text not null,
  amount numeric(14,2) not null check (amount >= 0),
  due_date date,
  status text not null default 'unpaid' check (status in ('unpaid','paid','overdue')),
  assigned_to uuid references profiles(id) on delete set null,
  document_id uuid references documents(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references profiles(id) on delete cascade,
  desk_id uuid references desks(id) on delete cascade,
  assignee_id uuid references profiles(id) on delete set null,
  title text not null,
  description text,
  due_date timestamptz,
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  status text not null default 'pending' check (status in ('pending','in_progress','completed')),
  created_at timestamptz not null default now()
);

create table if not exists khata_entries (
  id uuid primary key default gen_random_uuid(),
  desk_id uuid references desks(id) on delete cascade,
  created_by uuid not null references profiles(id) on delete cascade,
  creditor_id uuid not null references profiles(id) on delete cascade,
  debtor_id uuid not null references profiles(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  status text not null default 'open' check (status in ('open','settled')),
  created_at timestamptz not null default now(),
  settled_at timestamptz
);

create table if not exists activity_events (
  id uuid primary key default gen_random_uuid(),
  desk_id uuid references desks(id) on delete cascade,
  actor_id uuid references profiles(id) on delete set null,
  event_type text not null,
  entity_type text not null,
  entity_id uuid,
  summary text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_documents_owner on documents(owner_id);
create index if not exists idx_documents_desk on documents(desk_id);
create index if not exists idx_bills_desk on bills(desk_id);
create index if not exists idx_tasks_desk on tasks(desk_id);
create index if not exists idx_tasks_assignee on tasks(assignee_id);
create index if not exists idx_khata_desk on khata_entries(desk_id);

alter table profiles enable row level security;
alter table desks enable row level security;
alter table desk_members enable row level security;
alter table documents enable row level security;
alter table bills enable row level security;
alter table tasks enable row level security;
alter table khata_entries enable row level security;
alter table activity_events enable row level security;

create policy "Users can read own profile" on profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

create policy "Members can view desks" on desks for select using (
  owner_id = auth.uid() or exists (
    select 1 from desk_members dm where dm.desk_id = desks.id and dm.user_id = auth.uid()
  )
);

create policy "Owners can manage desks" on desks for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "Members can view desk membership" on desk_members for select using (
  user_id = auth.uid() or exists (
    select 1 from desks d where d.id = desk_members.desk_id and d.owner_id = auth.uid()
  )
);

create policy "Owners can manage desk membership" on desk_members for all using (
  exists (select 1 from desks d where d.id = desk_members.desk_id and d.owner_id = auth.uid())
) with check (
  exists (select 1 from desks d where d.id = desk_members.desk_id and d.owner_id = auth.uid())
);

create policy "Users can view accessible documents" on documents for select using (
  owner_id = auth.uid() or (
    desk_id is not null and exists (
      select 1 from desk_members dm where dm.desk_id = documents.desk_id and dm.user_id = auth.uid()
    )
  )
);

create policy "Users can create own documents" on documents for insert with check (owner_id = auth.uid());
create policy "Owners can update documents" on documents for update using (owner_id = auth.uid());
create policy "Owners can delete documents" on documents for delete using (owner_id = auth.uid());

create policy "Desk members can view bills" on bills for select using (
  owner_id = auth.uid() or (desk_id is not null and exists (
    select 1 from desk_members dm where dm.desk_id = bills.desk_id and dm.user_id = auth.uid()
  ))
);
create policy "Users can create bills" on bills for insert with check (owner_id = auth.uid());
create policy "Owners and assignees can update bills" on bills for update using (owner_id = auth.uid() or assigned_to = auth.uid());

create policy "Desk members can view tasks" on tasks for select using (
  creator_id = auth.uid() or assignee_id = auth.uid() or (desk_id is not null and exists (
    select 1 from desk_members dm where dm.desk_id = tasks.desk_id and dm.user_id = auth.uid()
  ))
);
create policy "Users can create tasks" on tasks for insert with check (creator_id = auth.uid());
create policy "Creators and assignees can update tasks" on tasks for update using (creator_id = auth.uid() or assignee_id = auth.uid());

create policy "Khata participants can view entries" on khata_entries for select using (
  creditor_id = auth.uid() or debtor_id = auth.uid() or created_by = auth.uid()
);
create policy "Users can create khata entries" on khata_entries for insert with check (created_by = auth.uid());
create policy "Participants can update khata entries" on khata_entries for update using (
  creditor_id = auth.uid() or debtor_id = auth.uid() or created_by = auth.uid()
);

create policy "Desk members can view activity" on activity_events for select using (
  actor_id = auth.uid() or (desk_id is not null and exists (
    select 1 from desk_members dm where dm.desk_id = activity_events.desk_id and dm.user_id = auth.uid()
  ))
);
