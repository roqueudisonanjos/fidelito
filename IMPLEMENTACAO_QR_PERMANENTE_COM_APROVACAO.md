# QR permanente com solicitação e aprovação de pontos

## Fluxo
- QR temporário: mantém o crédito imediato e o uso único.
- QR permanente: cada leitura cria uma solicitação pendente. O saldo não é alterado até a empresa aprovar.
- Cliente pode repetir o mesmo QR depois que a solicitação anterior for aprovada ou rejeitada.
- Leituras repetidas enquanto já existe uma solicitação pendente para o mesmo cliente e QR não criam duplicatas pendentes; o app informa que a solicitação já está aguardando.
- A empresa pode aprovar ou rejeitar na página `Solicitações de pontos` do portal.
- Aprovação adiciona pontos, grava uma transação de histórico e notifica o cliente. Rejeição notifica o cliente sem creditar pontos.
- O card do portal mostra o total de solicitações pendentes e atualiza periodicamente enquanto a página inicial da empresa está aberta.

## Migração Supabase

Execute o arquivo `20261119000200_static_qr_points_approval.sql` no SQL Editor do Supabase, após as migrações anteriores do projeto, incluindo a de QR permanente `20261119000100_static_printable_qr_codes.sql`.


## Observação
A atualização de notificações do portal empresarial usa polling enquanto a home da empresa está aberta (intervalo de 20 segundos); não é push do sistema operacional. O status e o crédito são protegidos por funções PostgreSQL transacionais e RLS.
