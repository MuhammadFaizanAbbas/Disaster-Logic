-- Transactional fixtures: no test users, bookings or workspaces survive this test.
begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('10000000-0000-4000-8000-000000000001','schema-admin@example.invalid',now(),'{"full_name":"Test Admin"}'),
 ('10000000-0000-4000-8000-000000000002','schema-member@example.invalid',now(),'{"full_name":"Test Member"}'),
 ('10000000-0000-4000-8000-000000000003','schema-referral@example.invalid',now(),'{"full_name":"Test Referral"}'),
 ('10000000-0000-4000-8000-000000000004','schema-outsider@example.invalid',now(),'{"full_name":"Test Outsider"}'),
 ('10000000-0000-4000-8000-000000000005','schema-partner@example.invalid',now(),'{"full_name":"Test Partner"}');
update public.profiles set is_platform_admin=true where id='10000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","email":"schema-admin@example.invalid"}',true);
do $$ declare r jsonb; sid uuid; begin
 select id into sid from public.services where code='water-damage-pipe-burst';
 r:=public.create_workspace('Schema Test A','schema-test-a','schema-admin@example.invalid',array[sid]);
 perform set_config('test.ws_a',r->>'id',true); perform set_config('test.public_key',r->>'public_key',true);
 r:=public.create_workspace('Schema Test B','schema-test-b','schema-partner@example.invalid',array[sid]);
 perform set_config('test.ws_b',r->>'id',true);
 perform public.add_workspace_member(current_setting('test.ws_a')::uuid,'schema-member@example.invalid');
 insert into public.workspace_locations(workspace_id,name,postal_codes) values(current_setting('test.ws_b')::uuid,'Coverage',array['77002']);
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","email":"schema-member@example.invalid"}',true);
do $$ declare r jsonb; pid uuid; i jsonb; begin
 r:=public.submit_booking(current_setting('test.public_key'),'Test Customer','+15550000000','customer@example.invalid','77002','water-damage-pipe-burst','scheduled','Water leak',current_date+1,'12:00-16:00',2,'private');
 perform set_config('test.opp',r->>'opportunity_id',true);
 pid:=public.accept_opportunity((r->>'opportunity_id')::uuid,current_setting('test.ws_a')::uuid);
 perform set_config('test.project',pid::text,true);
 if (select count(*) from public.project_steps where project_id=pid)<>7 then raise exception 'Expected seven project steps'; end if;
 if (select status from public.opportunities where id=(r->>'opportunity_id')::uuid)<>'accepted' then raise exception 'Opportunity not converted'; end if;
 begin perform public.accept_opportunity((r->>'opportunity_id')::uuid,current_setting('test.ws_a')::uuid);raise exception 'Duplicate acceptance permitted';exception when raise_exception then if sqlerrm='Duplicate acceptance permitted' then raise;end if;end;
 i:=public.create_referral(pid,'individual','Test Referral','schema-referral@example.invalid',null,null,100,'Test invitation');
 perform set_config('test.invite',i->>'id',true);perform set_config('test.token',i->>'token',true);
 perform public.save_project_step(pid,'evaluate','{"notes":"Water assessment"}',true);
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","email":"schema-outsider@example.invalid"}',true);
do $$ begin
 if exists(select 1 from public.projects) then raise exception 'Outsider can read projects';end if;
 if exists(select 1 from public.customers) then raise exception 'Outsider can read customers';end if;
 begin perform public.set_project_status(current_setting('test.project')::uuid,'in_progress');raise exception 'Outsider status write permitted';exception when insufficient_privilege then null;end;
 begin perform public.claim_referral(current_setting('test.token'));raise exception 'Wrong recipient claim permitted';exception when insufficient_privilege then null;end;
 begin update public.profiles set is_platform_admin=true where id=auth.uid();raise exception 'Self-promotion permitted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","email":"schema-referral@example.invalid"}',true);
do $$ declare pid uuid; begin
 pid:=public.claim_referral(current_setting('test.token'));
 if pid<>current_setting('test.project')::uuid then raise exception 'Claim returned wrong project';end if;
 begin perform public.claim_referral(current_setting('test.token'));raise exception 'Duplicate claim permitted';exception when no_data_found then null;end;
 if (select count(*) from public.projects)<>1 then raise exception 'Referral access is not project scoped';end if;
 if exists(select 1 from public.workspace_members where user_id=auth.uid() and member_type='internal') then raise exception 'Referral became an internal user';end if;
 perform public.set_project_status(pid,'in_progress');
 begin perform public.set_project_status(pid,'completed');raise exception 'Referral completion permitted';exception when insufficient_privilege then null;when raise_exception then if sqlerrm='Referral completion permitted' then raise;end if;end;
 begin perform public.save_customer(current_setting('test.ws_a')::uuid,'Unauthorized','bad@example.invalid');raise exception 'Referral created customer';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","email":"schema-admin@example.invalid"}',true);
do $$ begin
 perform public.update_member_settings(current_setting('test.ws_a')::uuid,'10000000-0000-4000-8000-000000000003',null,'disabled');
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","email":"schema-referral@example.invalid"}',true);
do $$ begin
 if exists(select 1 from public.projects) then raise exception 'Disabled referral still has access';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","email":"schema-admin@example.invalid"}',true);
do $$ declare b jsonb;i jsonb;pid uuid;begin
 b:=public.submit_booking(current_setting('test.public_key'),'Workspace Referral Customer','+15550000002','workspace-client@example.invalid','77002','water-damage-pipe-burst');
 i:=public.refer_opportunity((b->>'opportunity_id')::uuid,current_setting('test.ws_a')::uuid,'workspace',null,null,null,current_setting('test.ws_b')::uuid,200,'Workspace assignment');
 perform set_config('test.ws_invite',i->>'id',true);
 b:=public.submit_booking(current_setting('test.public_key'),'Open Listing Customer','+15550000003','open-client@example.invalid','77002','water-damage-pipe-burst');
 i:=public.refer_opportunity((b->>'opportunity_id')::uuid,current_setting('test.ws_a')::uuid,'opportunities',null,null,null,null,300,'Open assignment');
 perform set_config('test.board_invite',i->>'id',true);
end $$;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","role":"authenticated","email":"schema-partner@example.invalid"}',true);
do $$ declare pid uuid;board jsonb;begin
 board:=public.referral_board();
 if jsonb_array_length(board)<>2 then raise exception 'Expected workspace and matching open referrals';end if;
 pid:=public.accept_referral_listing(current_setting('test.ws_invite')::uuid,current_setting('test.ws_b')::uuid);
 if (select workspace_id from public.projects where id=pid)<>current_setting('test.ws_a')::uuid then raise exception 'Referral incorrectly moved workspace ownership';end if;
 pid:=public.accept_referral_listing(current_setting('test.board_invite')::uuid,current_setting('test.ws_b')::uuid);
 if jsonb_array_length(public.referral_board())<>0 then raise exception 'Claimed referrals remained on board';end if;
 if (select count(*) from public.projects)<>2 then raise exception 'Partner project access is incorrect';end if;
 if exists(select 1 from public.project_steps where step in ('claim','contracts','payments')) then raise exception 'Referral can read financial workflow records';end if;
end $$;
rollback;
select 'PASS: booking, acceptance, seven steps, recipient checks, tenant isolation, disabled access, and guarded mutations' result;
