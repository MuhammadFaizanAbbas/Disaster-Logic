alter type public.referral_target add value if not exists 'opportunities';
do $$ begin
  create type public.payment_status as enum ('pending','partial','paid');
exception when duplicate_object then null; end $$;
