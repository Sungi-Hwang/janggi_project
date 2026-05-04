create or replace function public.soft_delete_community_puzzle(
  target_puzzle_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_puzzles
  set
    status = 'deleted',
    updated_at = now()
  where id = target_puzzle_id
    and author_id = auth.uid();

  if not found then
    raise exception 'not_allowed'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.soft_delete_community_puzzle(uuid) from public;
grant execute on function public.soft_delete_community_puzzle(uuid)
  to authenticated;
