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

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Configuração ausente no servidor: ${name}`);
  return value;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);

  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) {
      return json({ error: 'Autenticação obrigatória.' }, 401);
    }

    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');

    // O token do usuário é validado com a chave pública. Nunca confiamos em
    // um user_id enviado pelo Flutter para conceder privilégios.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const accessToken = authorization.substring('Bearer '.length);
    const { data: userData, error: userError } = await userClient.auth.getUser(accessToken);
    if (userError || !userData.user) return json({ error: 'Sessão inválida ou expirada.' }, 401);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json().catch(() => ({}));
    const action = typeof body.action === 'string' ? body.action : '';

    const { data: adminRecord, error: adminCheckError } = await adminClient
      .from('fidelito_admins')
      .select('user_id')
      .eq('user_id', userData.user.id)
      .maybeSingle();

    if (adminCheckError) {
      console.error('Falha ao validar administrador:', adminCheckError.message);
      return json({ error: 'Não foi possível validar o acesso administrativo. Execute a migração do painel.' }, 500);
    }

    if (action === 'check_access') {
      return json({ is_admin: !!adminRecord });
    }

    if (!adminRecord) return json({ error: 'Acesso restrito à administração do Fidelito.' }, 403);

    const audit = async (
      actionName: string,
      targetType: string,
      targetId: string,
      details: Record<string, unknown> = {},
    ) => {
      const { error } = await adminClient.from('fidelito_admin_audit_log').insert({
        actor_user_id: userData.user.id,
        action: actionName,
        target_type: targetType,
        target_id: targetId,
        details,
      });
      if (error) console.error('Não foi possível registrar auditoria:', error.message);
    };

    if (action === 'list_customers') {
      const { data: profiles, error } = await adminClient
        .from('profiles')
        .select('id, full_name, phone, role, avatar_url')
        .eq('role', 'customer')
        .order('full_name', { ascending: true })
        .limit(1000);
      if (error) throw error;

      const { data: authUsers, error: usersError } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (usersError) throw usersError;
      const usersById = new Map(authUsers.users.map((u) => [u.id, u]));
      const term = String(body.query ?? '').trim().toLocaleLowerCase('pt-BR');

      const customers = (profiles ?? []).map((profile) => {
        const authUser = usersById.get(profile.id);
        return {
          id: profile.id,
          full_name: profile.full_name ?? 'Cliente sem nome',
          avatar_url: profile.avatar_url ?? null,
          phone: profile.phone ?? '',
          email: authUser?.email ?? '',
          created_at: authUser?.created_at ?? null,
          last_sign_in_at: authUser?.last_sign_in_at ?? null,
          email_confirmed: !!authUser?.email_confirmed_at,
        };
      }).filter((customer) => !term ||
        String(customer.full_name).toLocaleLowerCase('pt-BR').includes(term) ||
        String(customer.email).toLocaleLowerCase('pt-BR').includes(term) ||
        String(customer.phone).toLocaleLowerCase('pt-BR').includes(term));

      return json({ customers });
    }

    if (action === 'list_companies') {
      const { data: companies, error } = await adminClient
        .from('companies')
        .select('id, owner_id, name, phone, address, city, state, logo_url, active, suspended_at, deleted_at, created_at')
        .order('name', { ascending: true })
        .limit(1000);
      if (error) throw error;

      const ownerIds = [...new Set((companies ?? []).map((c) => c.owner_id).filter(Boolean))];
      const { data: owners, error: ownersError } = ownerIds.length
        ? await adminClient.from('profiles').select('id, full_name, phone').in('id', ownerIds)
        : { data: [], error: null };
      if (ownersError) throw ownersError;

      const { data: authUsers, error: usersError } = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (usersError) throw usersError;
      const ownersById = new Map((owners ?? []).map((o) => [o.id, o]));
      const usersById = new Map(authUsers.users.map((u) => [u.id, u]));
      const term = String(body.query ?? '').trim().toLocaleLowerCase('pt-BR');

      const result = (companies ?? []).map((company) => {
        const owner = ownersById.get(company.owner_id);
        const authUser = usersById.get(company.owner_id);
        return {
          ...company,
          owner_name: owner?.full_name ?? 'Responsável não identificado',
          owner_phone: owner?.phone ?? '',
          owner_email: authUser?.email ?? '',
        };
      }).filter((company) => !term ||
        String(company.name).toLocaleLowerCase('pt-BR').includes(term) ||
        String(company.owner_name).toLocaleLowerCase('pt-BR').includes(term) ||
        String(company.owner_email).toLocaleLowerCase('pt-BR').includes(term) ||
        String(company.city ?? '').toLocaleLowerCase('pt-BR').includes(term));

      return json({ companies: result });
    }

    if (action === 'generate_recovery_link') {
      const userId = String(body.user_id ?? '');
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
        return json({ error: 'Identificador de cliente inválido.' }, 400);
      }

      const { data: targetData, error: targetError } = await adminClient.auth.admin.getUserById(userId);
      if (targetError || !targetData.user?.email) return json({ error: 'Não foi possível localizar o e-mail desta conta.' }, 404);
      const profile = await adminClient.from('profiles').select('id, role').eq('id', userId).maybeSingle();
      if (profile.error) throw profile.error;
      if (!profile.data || profile.data.role !== 'customer') return json({ error: 'A conta selecionada não é de um cliente.' }, 400);

      const siteUrl = Deno.env.get('FIDELITO_SITE_URL')?.replace(/\/$/, '');
      const { data: linkData, error: linkError } = await adminClient.auth.admin.generateLink({
        type: 'recovery',
        email: targetData.user.email,
        ...(siteUrl ? { options: { redirectTo: `${siteUrl}/reset-password` } } : {}),
      });
      if (linkError) throw linkError;
      const recoveryLink = linkData.properties?.action_link;
      if (!recoveryLink) throw new Error('O Supabase não retornou o link de recuperação.');

      await audit('generate_recovery_link', 'customer', userId, {});
      return json({ recovery_link: recoveryLink, email: targetData.user.email });
    }

    if (action === 'delete_customer_account_admin') {
      const userId = String(body.user_id ?? '');
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
        return json({ error: 'Identificador de cliente inválido.' }, 400);
      }

      const { data: profile, error: profileError } = await adminClient
        .from('profiles').select('id, role, full_name').eq('id', userId).maybeSingle();
      if (profileError) throw profileError;
      if (!profile || profile.role !== 'customer') {
        return json({ error: 'A conta selecionada não é de um cliente.' }, 404);
      }

      // Limpa os dados relacionados através da rotina segura existente antes de
      // remover o usuário do Supabase Auth.
      const { error: prepareError } = await adminClient.rpc(
        'prepare_customer_account_deletion', { p_user_id: userId },
      );
      if (prepareError) throw prepareError;


      // Remove imagens de perfil associadas ao usuário antes de excluir o Auth.
      const profilePrefix = `profiles/${userId}`;
      const { data: profileFiles, error: filesListError } = await adminClient.storage
        .from('fidelito-images').list(profilePrefix, { limit: 1000 });
      if (filesListError) throw new Error(`Não foi possível remover as imagens do cliente: ${filesListError.message}`);
      const profilePaths = (profileFiles ?? []).filter((file) => !!file.name).map((file) => `${profilePrefix}/${file.name}`);
      if (profilePaths.length) {
        const { error: filesRemoveError } = await adminClient.storage.from('fidelito-images').remove(profilePaths);
        if (filesRemoveError) throw new Error(`Não foi possível remover as imagens do cliente: ${filesRemoveError.message}`);
      }

      const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
      let accessBlocked = false;
      if (deleteError) {
        const { error: banError } = await adminClient.auth.admin.updateUserById(userId, { ban_duration: '876000h' });
        if (banError) throw new Error(`Dados do cliente removidos, mas não foi possível excluir nem bloquear o acesso: ${banError.message}`);
        accessBlocked = true;
      }

      await audit('admin_delete_customer_account', 'customer', userId, {
        customer_name: profile.full_name ?? null,
        access_blocked: accessBlocked,
      });
      return json({ success: true, user_id: userId, access_blocked: accessBlocked });
    }


    if (action === 'generate_company_recovery_link') {
      const companyId = String(body.company_id ?? '');
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId)) {
        return json({ error: 'Identificador de empresa inválido.' }, 400);
      }

      // O ID do responsável é obtido do registro da empresa no banco; não
      // aceitamos owner_id enviado pelo aplicativo.
      const { data: company, error: companyError } = await adminClient
        .from('companies')
        .select('id, name, owner_id')
        .eq('id', companyId)
        .maybeSingle();
      if (companyError) throw companyError;
      if (!company?.owner_id) {
        return json({ error: 'Não foi possível localizar o responsável desta empresa.' }, 404);
      }

      const { data: targetData, error: targetError } = await adminClient.auth.admin.getUserById(company.owner_id);
      if (targetError || !targetData.user?.email) {
        return json({ error: 'Não foi possível localizar o e-mail da conta responsável.' }, 404);
      }

      const { data: profile, error: profileError } = await adminClient
        .from('profiles')
        .select('id, role')
        .eq('id', company.owner_id)
        .maybeSingle();
      if (profileError) throw profileError;
      if (!profile) {
        return json({ error: 'O perfil do responsável não foi encontrado.' }, 404);
      }

      const siteUrl = Deno.env.get('FIDELITO_SITE_URL')?.replace(/\/$/, '');
      const { data: linkData, error: linkError } = await adminClient.auth.admin.generateLink({
        type: 'recovery',
        email: targetData.user.email,
        ...(siteUrl ? { options: { redirectTo: `${siteUrl}/reset-password` } } : {}),
      });
      if (linkError) throw linkError;
      const recoveryLink = linkData.properties?.action_link;
      if (!recoveryLink) throw new Error('O Supabase não retornou o link de recuperação.');

      await audit('generate_recovery_link', 'company_owner', company.owner_id, {
        company_id: company.id,
        company_name: company.name,
      });
      return json({
        recovery_link: recoveryLink,
        email: targetData.user.email,
        company_id: company.id,
      });
    }

    if (action === 'delete_company_account_admin') {
      const companyId = String(body.company_id ?? '');
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId)) {
        return json({ error: 'Identificador de empresa inválido.' }, 400);
      }

      const { data: company, error: companyError } = await adminClient
        .from('companies')
        .select('id, name, owner_id, active, suspended_at, deleted_at')
        .eq('id', companyId)
        .maybeSingle();
      if (companyError) throw companyError;
      if (!company) return json({ error: 'Empresa não encontrada.' }, 404);
      if (company.deleted_at) return json({ error: 'A conta desta empresa já foi excluída.' }, 409);
      if (company.active || !company.suspended_at) return json({ error: 'Desative a empresa pelo painel antes de excluir a conta.' }, 409);
      if (!company.owner_id) return json({ error: 'Não foi possível localizar o responsável pela conta.' }, 409);

      const ownerId = company.owner_id;
      const { data: profile, error: profileError } = await adminClient
        .from('profiles').select('id, role').eq('id', ownerId).maybeSingle();
      if (profileError) throw profileError;
      if (!profile || profile.role !== 'company_owner') {
        return json({ error: 'O responsável não possui um perfil válido de empresa.' }, 409);
      }

      // Reutiliza a mesma rotina de encerramento da conta empresarial usada
      // pelo próprio responsável. Ela exige que TODAS as empresas vinculadas
      // a esse usuário estejam desativadas, preserva os registros históricos,
      // encerra as fidelidades e notifica os clientes.
      const { data: deletionResult, error: prepareError } = await adminClient.rpc(
        'prepare_company_account_deletion', { p_user_id: ownerId },
      );
      if (prepareError) throw prepareError;

      // Remove arquivos de imagem pertencentes ao responsável, sem expor a
      // chave service_role ao aplicativo Flutter.
      for (const folder of ['profiles', 'companies', 'promotions']) {
        const prefix = `${folder}/${ownerId}`;
        const { data: files, error: listError } = await adminClient.storage
          .from('fidelito-images').list(prefix, { limit: 1000 });
        if (listError) throw new Error(`Não foi possível remover as imagens da empresa: ${listError.message}`);
        const paths = (files ?? []).filter((file) => !!file.name).map((file) => `${prefix}/${file.name}`);
        if (paths.length) {
          const { error: removeError } = await adminClient.storage.from('fidelito-images').remove(paths);
          if (removeError) throw new Error(`Não foi possível remover as imagens da empresa: ${removeError.message}`);
        }
      }

      const { error: deleteError } = await adminClient.auth.admin.deleteUser(ownerId);
      let accessBlocked = false;
      if (deleteError) {
        const { error: banError } = await adminClient.auth.admin.updateUserById(ownerId, { ban_duration: '876000h' });
        if (banError) throw new Error(`A empresa foi encerrada, mas não foi possível excluir nem bloquear a conta do responsável: ${banError.message}`);
        accessBlocked = true;
      }

      await audit('admin_delete_company_account', 'company', companyId, {
        company_name: company.name,
        owner_id: ownerId,
        customers_notified: deletionResult?.customers_notified ?? 0,
        access_blocked: accessBlocked,
      });
      return json({
        success: true,
        company_id: companyId,
        customers_notified: deletionResult?.customers_notified ?? 0,
        access_blocked: accessBlocked,
      });
    }

    if (action === 'set_company_active') {
      const companyId = String(body.company_id ?? '');
      const active = body.active;
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId) || typeof active !== 'boolean') {
        return json({ error: 'Dados inválidos para atualizar a empresa.' }, 400);
      }

      const { data: existingCompany, error: companyError } = await adminClient
        .from('companies')
        .select('id, name, owner_id, active')
        .eq('id', companyId)
        .single();
      if (companyError) throw companyError;

      // Atualiza o status e cria as notificações numa única transação SQL.
      // A função é acessível somente à service_role.
      const { data: result, error: suspensionError } = await adminClient.rpc(
        'set_company_active_with_notifications',
        { p_company_id: companyId, p_active: active },
      );
      if (suspensionError) throw suspensionError;

      // Bloqueia novos logins e renovações de sessão do responsável. A rota
      // da empresa também consulta companies.active para bloquear sessões já abertas.
      if (existingCompany.owner_id) {
        const { error: authUpdateError } = await adminClient.auth.admin.updateUserById(
          existingCompany.owner_id,
          { ban_duration: active ? 'none' : '876000h' },
        );
        if (authUpdateError) {
          console.error('Falha ao atualizar bloqueio Auth da empresa:', authUpdateError.message);
          return json({
            error: active
              ? 'Empresa reativada no banco, mas não foi possível liberar o login. Tente novamente.'
              : 'Empresa suspensa e clientes notificados, mas não foi possível bloquear o login do responsável. Tente novamente.',
            company: result?.company ?? null,
            customers_notified: result?.customers_notified ?? 0,
          }, 500);
        }
      }

      await audit(active ? 'activate_company' : 'deactivate_company', 'company', companyId, {
        active,
        customers_notified: result?.customers_notified ?? 0,
      });
      return json({
        company: result?.company ?? { id: companyId, name: existingCompany.name, active },
        customers_notified: result?.customers_notified ?? 0,
      });
    }

    return json({ error: 'Ação administrativa desconhecida.' }, 400);
  } catch (error) {
    console.error('Erro no admin-console:', error);
    const message = error instanceof Error ? error.message : 'Erro interno no painel administrativo.';
    return json({ error: message }, 500);
  }
});
