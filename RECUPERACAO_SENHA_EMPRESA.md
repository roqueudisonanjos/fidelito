# Recuperação de senha de empresa no painel administrativo

Foi adicionada à aba **Empresas** a ação **Gerar link de recuperação de senha**.

## Funcionamento

1. O administrador localiza a empresa na aba Empresas.
2. Clica em **Gerar link de recuperação de senha**.
3. Confirma que verificou a identidade do responsável por um canal confiável.
4. O painel chama a Edge Function `admin-console` enviando apenas o ID da empresa.
5. A função consulta o `owner_id` diretamente na tabela `companies`, localiza o e-mail correspondente no Supabase Auth e gera um link oficial de recuperação.
6. O painel exibe o link para copiar e enviar exclusivamente ao responsável verificado.
7. O responsável abre o link e define a nova senha na tela `/reset-password` do Fidelito.

## Segurança

- A função exige sessão válida e verifica se o usuário está cadastrado em `fidelito_admins`.
- O Flutter envia `company_id`, não um `user_id` arbitrário.
- O servidor determina o responsável consultando `companies.owner_id`.
- A `SUPABASE_SERVICE_ROLE_KEY` permanece somente nos secrets/ambiente da Edge Function.
- A geração é registrada em `fidelito_admin_audit_log` como `company_owner`, incluindo o ID e o nome da empresa, mas nunca o link secreto.
- Antes de gerar e enviar, o administrador deve confirmar a identidade do responsável.

## Implantação

Não há migração SQL nova. Publique a função atualizada:

```powershell
supabase functions deploy admin-console
```

Mantenha configurado no Supabase Auth o Redirect URL:

```text
https://fidelito.web.app/reset-password
```
