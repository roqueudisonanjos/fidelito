# Encerramento de contas, notificações e suporte ApoloApps

## O que foi incluído

- Cliente: opção de excluir a conta em **Dados cadastrais**. A tela exige a senha atual para reautenticar a pessoa antes da operação. A Edge Function remove resgates, transações e contas de fidelidade do cliente e, por fim, exclui a identidade no Supabase Auth.
- Empresa: opção de encerrar a conta em **Dados da empresa**. Também está disponível enquanto o cadastro estiver em análise. A operação avisa os participantes ativos, desativa a empresa e seus benefícios, zera os saldos e encerra as adesões.
- Cliente: sino de notificações na tela inicial e página de notificações; o cliente pode abrir uma notificação para marcá-la como lida.
- Cliente e empresa: botão de suporte ApoloApps no topo das telas iniciais. O WhatsApp abre com a mensagem `Preciso de ajuda`.

## Comportamento e retenção da conta empresarial

Para preservar o registro da empresa, a referência das notificações e o histórico administrativo, a operação empresarial **desativa** a empresa e bloqueia a conta Auth do responsável por prazo longo (banimento administrativo), em vez de apagar fisicamente a identidade e correr o risco de apagar a própria empresa por cascata de chaves estrangeiras. O responsável não consegue mais entrar; o registro empresarial permanece inativo no banco. A conta de cliente, por outro lado, é removida do Supabase Auth após a limpeza dos dados de fidelidade.

## Migração SQL

Execute no Supabase SQL Editor, após as migrações anteriores:

`supabase/migrations/20261115000300_account_deletion_notifications.sql`

Ela cria `user_notifications`, as políticas para cada usuário consultar/marcar apenas as próprias notificações e a coluna `companies.deleted_at`.

## Publicar Edge Function

No terminal, dentro da pasta do projeto:

```bash
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy account-management
```

A função usa `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` como secrets padrão do ambiente Supabase. Não coloque a chave `service_role` no Flutter nem em variáveis `--dart-define`.

## Configurar WhatsApp profissional ApoloApps

O número é lido da configuração `SUPPORT_WHATSAPP`, já usada pelo app. Informe o número internacional apenas com dígitos (55 + DDD + número), sem `+`, espaços ou pontuação:

```bash
flutter build web --release --dart-define=SUPPORT_WHATSAPP=55DDDNÚMERO
```

Use o comando de build correspondente à plataforma de publicação, mantendo o mesmo `--dart-define`.

## Validação sugerida

```bash
flutter pub get
flutter analyze
flutter test
```

Teste primeiro com contas de homologação: cliente com pontos/resgates e empresa com pelo menos um cliente participante. Confirme que a notificação aparece no sino do cliente, os pontos zeram e a empresa/benefícios deixam de aparecer como ativos.
