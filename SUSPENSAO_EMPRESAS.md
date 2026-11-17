# Suspensão administrativa de empresas

## Comportamento

- A ação **Desativar empresa** no painel administrativo suspende o programa.
- Cada cliente com adesão ativa recebe uma notificação informando que não poderá usar os pontos nem realizar resgates enquanto durar a suspensão.
- Os saldos e históricos são preservados. As adesões não são encerradas.
- O responsável pela empresa é bloqueado no Supabase Auth (`ban_duration`) e não consegue iniciar novas sessões.
- Sessões que já estavam abertas são encaminhadas para a tela **Empresa suspensa**, que bloqueia o acesso às demais áreas do aplicativo.
- A reativação limpa `suspended_at`, libera novamente o usuário no Auth e restaura a disponibilidade dos dados preservados.
- A suspensão não desativa definitivamente promoções nem QR Codes; as operações existentes que verificam `companies.active` impedem seu uso enquanto a empresa estiver suspensa.

## Aplicação

1. Faça backup do banco.
2. Execute `supabase/migrations/20261116000100_company_suspension.sql` no SQL Editor do Supabase.
3. Publique a Edge Function atualizada:

   ```powershell
   supabase functions deploy admin-console
   ```

4. Atualize o aplicativo Flutter e execute:

   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   ```

A migração cria a coluna `companies.suspended_at` e uma função SQL restrita à `service_role`. Não execute a chave `service_role` no aplicativo Flutter.
