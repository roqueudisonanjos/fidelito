-- Painel administrativo do Fidelito.
-- O primeiro administrador é cadastrado manualmente usando o UUID de uma conta
-- previamente criada em Authentication > Users.
-- Esta tabela não pode ser consultada ou alterada pelo aplicativo cliente.

BEGIN;

CREATE TABLE IF NOT EXISTS public.fidelito_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.fidelito_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.fidelito_admins FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.fidelito_admins TO service_role;

CREATE TABLE IF NOT EXISTS public.fidelito_admin_audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id),
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fidelito_admin_audit_log_created_at_idx
  ON public.fidelito_admin_audit_log (created_at DESC);

CREATE INDEX IF NOT EXISTS fidelito_admin_audit_log_target_idx
  ON public.fidelito_admin_audit_log (target_type, target_id, created_at DESC);

ALTER TABLE public.fidelito_admin_audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.fidelito_admin_audit_log FROM PUBLIC, anon, authenticated;
GRANT INSERT, SELECT ON TABLE public.fidelito_admin_audit_log TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.fidelito_admin_audit_log_id_seq TO service_role;

COMMIT;

-- Depois de criar a conta que será a administradora do Fidelito, copie o UUID
-- dela em Authentication > Users e execute separadamente:
-- INSERT INTO public.fidelito_admins (user_id)
-- VALUES ('UUID-DA-CONTA-ADMIN');
