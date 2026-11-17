# Exclusão de conta empresarial pelo painel administrativo

A lista de empresas no painel administrativo agora oferece **Excluir conta da empresa** somente quando a empresa foi efetivamente suspensa pelo painel (active=false e suspended_at preenchido). Empresas ativas ou apenas pendentes não podem ser excluídas por esta ação.

A Edge Function `admin-console` valida o administrador autenticado, consulta o responsável diretamente no banco, reutiliza `prepare_company_account_deletion` (a mesma rotina de encerramento da conta empresarial), encerra as participações, zera os pontos remanescentes, notifica os clientes, desativa promoções, preserva os registros históricos e remove as imagens da conta. Em seguida exclui o usuário do Supabase Auth; se a exclusão Auth falhar, tenta bloquear a conta. A operação é registrada em `fidelito_admin_audit_log`.

Se o mesmo responsável possuir mais de uma empresa, a rotina de encerramento alcança todas as empresas vinculadas àquela conta e exige que todas estejam desativadas.

## Publicação

Não há nova migração SQL: a implementação utiliza a função `prepare_company_account_deletion` e as colunas criadas pelas migrações anteriores, especialmente `20261115000300_account_deletion_notifications.sql` e `20261116000200_profiles_and_reward_images_account_rules.sql`.

Publique a Edge Function atualizada:

```powershell
supabase functions deploy admin-console
```

Depois, execute `flutter pub get`, `flutter analyze` e `flutter test`.
