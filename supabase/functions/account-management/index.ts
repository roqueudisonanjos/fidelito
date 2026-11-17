import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
);
function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Configuração ausente no servidor: ${name}`);
  return value;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);

  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'Autenticação obrigatória.' }, 401);

    const url = env('SUPABASE_URL');
    const anonKey = env('SUPABASE_ANON_KEY');
    const serviceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
    const accessToken = authorization.slice('Bearer '.length);

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(accessToken);
    if (authError || !authData.user) return json({ error: 'Sessão inválida ou expirada.' }, 401);
    const user = authData.user;

    const admin = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? '');

    async function removeUserImages(folders: string[]) {
      for (const folder of folders) {
        const prefix = `${folder}/${user.id}`;
        const { data: files, error: listError } = await admin.storage
          .from('fidelito-images').list(prefix, { limit: 1000 });
        if (listError) throw new Error(`Não foi possível preparar a remoção das imagens (${folder}): ${listError.message}`);
        const paths = (files ?? [])
          .filter((file) => !!file.name)
          .map((file) => `${prefix}/${file.name}`);
        if (paths.length) {
          const { error: removeError } = await admin.storage.from('fidelito-images').remove(paths);
          if (removeError) throw new Error(`Não foi possível remover as imagens (${folder}): ${removeError.message}`);
        }
      }
    }
    const { data: profile, error: profileError } = await admin
      .from('profiles').select('id, role').eq('id', user.id).maybeSingle();
    if (profileError) throw profileError;
    if (!profile) return json({ error: 'Perfil não encontrado.' }, 404);

    if (action === 'delete_customer_account') {
      if (String(profile.role) !== 'customer') return json({ error: 'Esta operação é exclusiva para contas de clientes.' }, 403);

      const { error: prepareError } = await admin.rpc('prepare_customer_account_deletion', {
        p_user_id: user.id,
      });
      if (prepareError) throw prepareError;
      await removeUserImages(['profiles']);

      const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
      if (deleteError) {
        // Se a exclusão Auth for impedida por uma referência legada, bloqueia
        // imediatamente o acesso para que a conta sem dados não continue ativa.
        const { error: banError } = await admin.auth.admin.updateUserById(user.id, { ban_duration: '876000h' });
        if (banError) throw new Error(`Dados de fidelidade removidos, mas não foi possível excluir nem bloquear o acesso: ${banError.message}`);
        return json({ success: true, account_type: 'customer', access_blocked: true });
      }
      return json({ success: true, account_type: 'customer' });
    }

    if (action === 'delete_company_account') {
      if (String(profile.role) !== 'company_owner') return json({ error: 'Esta operação é exclusiva para contas de empresas.' }, 403);

      // A função SQL exige que a empresa já esteja desativada.
      const { data: result, error: prepareError } = await admin.rpc('prepare_company_account_deletion', {
        p_user_id: user.id,
      });
      if (prepareError) throw prepareError;
      await removeUserImages(['companies', 'promotions']);

      const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
      if (deleteError) {
        const { error: banError } = await admin.auth.admin.updateUserById(user.id, { ban_duration: '876000h' });
        if (banError) throw new Error(`Empresa desativada, mas não foi possível excluir nem bloquear o acesso: ${banError.message}`);
        return json({ success: true, account_type: 'company', access_blocked: true, ...(result ?? {}) });
      }
      return json({ success: true, account_type: 'company', ...(result ?? {}) });
    }

    return json({ error: 'Ação desconhecida.' }, 400);
  } catch (error) {
    console.error('Falha ao encerrar conta:', error);
    return json({ error: error instanceof Error ? error.message : 'Não foi possível encerrar a conta.' }, 500);
  }
});
