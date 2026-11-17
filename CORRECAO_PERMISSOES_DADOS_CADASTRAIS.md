# Correção: atualização dos dados cadastrais

Esta atualização corrige o erro `permission denied for table companies` ao editar os dados cadastrais de clientes e empresas.

## O que mudou

- O aplicativo agora chama as funções `update_my_profile` e `update_my_company` no Supabase, em vez de executar `UPDATE` diretamente nas tabelas `profiles` e `companies`.
- As funções usam `auth.uid()` no servidor e só alteram o perfil do usuário autenticado ou a empresa cujo `owner_id` pertence a ele.
- Somente campos cadastrais permitidos são atualizados. O cliente não pode escolher outro `id` ou `owner_id`, nem alterar `role`, `active` ou outros campos administrativos.
- Não é necessário conceder `UPDATE` geral nas tabelas para `authenticated`.

## Passos obrigatórios no Supabase

1. Abra o projeto correto no Supabase.
2. Entre em **SQL Editor**.
3. Abra e execute o arquivo `supabase/migrations/20261117000100_secure_profile_company_updates.sql`.
4. Aguarde a execução terminar sem erros.
5. Publique a nova versão do aplicativo Flutter/Web que contém as chamadas RPC atualizadas.

Não execute `GRANT UPDATE ON public.companies TO authenticated` nem libere atualização geral nas tabelas. A correção foi feita por funções específicas para preservar a segurança entre contas.

## Testes recomendados

- Entrar como cliente e alterar nome, WhatsApp, cidade/UF e foto.
- Entrar como empresa e alterar nome, descrição, telefone, endereço, cidade/UF e logo.
- Confirmar que um cliente não consegue alterar o perfil de outro usuário e que uma empresa não consegue alterar outra empresa.
