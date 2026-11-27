# Painel administrativo do Vanty

Esta versão adiciona uma área exclusiva para a administração da plataforma, protegida no servidor. O painel permite:

- Pesquisar e consultar contas de clientes (nome, e-mail, telefone e situação de confirmação do e-mail).
- Gerar um link temporário de recuperação de senha para um cliente, depois de confirmar a identidade dele.
- Pesquisar empresas e consultar responsável, e-mail, telefone e localização.
- Ativar ou desativar empresas.
- Registrar as ações administrativas em `fidelito_admin_audit_log`.

Não há opção para apagar contas, empresas, pontos ou histórico. A desativação de uma empresa altera somente `companies.active`.

## 1. Criar a conta que será administradora

1. Crie uma conta normal no Vanty com o e-mail que será usado por você.
2. Confirme o e-mail e faça login pelo menos uma vez.
3. No Supabase, abra **Authentication > Users** e copie o UUID dessa conta.
4. Execute a migração `20261115000200_fidelito_admin_console.sql` no SQL Editor.
5. Depois da migração, execute este comando substituindo pelo UUID copiado:

```sql
INSERT INTO public.fidelito_admins (user_id)
VALUES ('UUID-DA-SUA-CONTA');
```

A tabela `fidelito_admins` não pode ser lida ou alterada pelo aplicativo. O cadastro inicial do administrador é feito manualmente pelo SQL Editor. Não coloque a chave `service_role` no Flutter.

Para remover o acesso administrativo posteriormente:

```sql
DELETE FROM public.fidelito_admins
WHERE user_id = 'UUID-DA-SUA-CONTA';
```

## 2. Implantar a função segura do Supabase

No terminal, dentro da pasta do projeto e com o Supabase CLI instalado e autenticado:

```bash
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy admin-console
supabase secrets set FIDELITO_SITE_URL=https://vanty.web.app
```

A função usa as variáveis fornecidas pelo ambiente do Supabase (`SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY`). A chave `service_role` permanece no servidor. A função valida o JWT do usuário e consulta `fidelito_admins` antes de executar qualquer ação administrativa.

O `verify_jwt = true` está configurado para a função `admin-console`.

## 3. Configurar o endereço de retorno da recuperação

No Supabase, abra **Authentication > URL Configuration**:

- Defina **Site URL** como `https://vanty.web.app`.
- Em **Redirect URLs**, adicione `https://vanty.web.app/reset-password`.
- Para desenvolvimento local, adicione também o endereço local que você realmente utiliza, por exemplo `http://localhost:PORT/reset-password`.

O link é criado pelo Supabase Auth como um link de recuperação de uso único. Ele redireciona para a rota `/reset-password` do Vanty, onde o próprio cliente escolhe a nova senha. A validade é controlada pelas configurações de Auth do projeto Supabase.

## 4. Usar o painel

1. Entre no Vanty com a conta que foi cadastrada em `fidelito_admins`.
2. O sistema direcionará essa conta para **Painel administrativo**.
3. Na aba **Clientes**, pesquise pelo nome, e-mail ou telefone.
4. Antes de gerar o link, confirme a identidade da pessoa por um canal confiável.
5. Clique em **Gerar link de recuperação de senha**, confirme a verificação e copie o link.
6. Envie o link somente ao titular da conta, pelo atendimento de WhatsApp. O cliente abre o link, define uma nova senha e volta a acessar o Vanty.
7. Na aba **Empresas**, pesquise e use os botões para ativar/desativar uma empresa.

## Segurança

- O Flutter nunca recebe a chave `service_role`.
- O cliente não consegue conceder a si mesmo acesso administrativo: a autorização é conferida no servidor contra `fidelito_admins`.
- Cada ação de recuperação e ativação/desativação é registrada na tabela de auditoria (sem armazenar o link secreto).
- O link de recuperação é sensível: não o registre em chamados, prints ou logs, e envie somente após verificar o titular.
- Não peça nem armazene a senha antiga do cliente. O próprio cliente define a nova senha no fluxo oficial do Supabase Auth.
- A recuperação depende de o projeto Supabase aceitar a URL de retorno configurada acima.

## Migrações

Execute as migrações em ordem, se ainda não tiver aplicado as anteriores:

1. `20261113000100_multi_company_loyalty.sql`
2. `20261114000100_profile_location_and_manual_points.sql`
3. `20261115000100_membership_exit_password_help.sql`
4. `20261115000200_fidelito_admin_console.sql`

Se as três primeiras já foram executadas, aplique somente a quarta.

## Recuperação de senha do responsável de uma empresa

Na aba **Empresas**, cada empresa agora possui o botão **Gerar link de recuperação de senha**. Antes de gerar o link, o painel solicita a confirmação de que a identidade do responsável foi verificada. O servidor recebe somente o `company_id`, consulta o `owner_id` diretamente na tabela `companies` e gera um link de recuperação para o e-mail da conta Auth vinculada. O aplicativo não pode informar livremente o usuário-alvo nem acessar a chave administrativa.

Depois de atualizar o projeto, publique novamente a função:

```bash
supabase functions deploy admin-console
```

Não é necessária nova migração SQL. A recuperação utiliza a tabela `companies`, a conta Auth do responsável e a tabela de auditoria já existentes. A URL `https://vanty.web.app/reset-password` deve continuar cadastrada nas Redirect URLs do Supabase Auth.


## Suspensão de empresas

A opção **Desativar empresa** suspende o programa, notifica os clientes com adesão ativa, preserva os pontos e bloqueia o login do responsável. Sessões abertas são encaminhadas à tela de empresa suspensa. Para habilitar novamente, use **Ativar empresa**. Execute também a migração `20261116000100_company_suspension.sql` e publique `supabase functions deploy admin-console`.

## Galeria de mídias em ofertas, recompensas e destaques

A migração `supabase/migrations/20261125000200_story_offer_multiple_media.sql` adiciona `media_urls` (até 5 URLs) às ofertas, recompensas e destaques, além do texto opcional dos destaques. Execute-a no SQL Editor do Supabase antes de publicar a versão atualizada do app.

Limites de upload no aplicativo: imagens até 5 MB por arquivo e vídeos até 15 MB por arquivo; cada publicação aceita no máximo 5 mídias. As imagens são reduzidas durante a seleção (largura máxima de 1600 px e qualidade 80). Vídeos são enviados sem recompressão e precisam respeitar o limite de tamanho.
