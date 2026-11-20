# Exclusão de conta pelo administrador e remoção de cliente da fidelidade

## 1) Exclusão de conta de cliente no painel administrativo

O painel administrativo agora oferece **Excluir conta do cliente**. A ação pede confirmação e chama a Edge Function `admin-console` com a ação `delete_customer_account_admin`. A função verifica o perfil de cliente, executa a rotina SQL existente `prepare_customer_account_deletion` para limpar registros de fidelidade relacionados e, em seguida, exclui o usuário do Supabase Auth. Se a exclusão do Auth falhar, tenta bloquear o acesso e retorna a condição ao administrador.

## 2) Remover cliente do programa da empresa

A tela **Meus clientes** oferece **Remover cliente do programa**, com confirmação. A ação chama `company_remove_customer_from_loyalty`, uma RPC que valida a empresa ativa pertencente ao usuário autenticado, encerra a adesão (`left_at`), zera o saldo remanescente, preserva transações/resgates e cria uma notificação ao cliente. A consulta existente em `DashboardService.getCompanyCustomers()` filtra `left_at IS NULL`, portanto o cliente deixa de aparecer para aquela empresa.

### Migration obrigatória

Execute `supabase/migrations/20261120000200_company_remove_loyalty_customer.sql` no SQL Editor do Supabase.

### Deploy da Edge Function

Publique a função `admin-console` atualizada:

```bash
supabase functions deploy admin-console
```

Depois, no projeto Flutter:

```bash
flutter pub get
flutter analyze
```

Não foi possível executar `flutter analyze`, compilação Flutter nem testar as operações contra o Supabase neste ambiente.
