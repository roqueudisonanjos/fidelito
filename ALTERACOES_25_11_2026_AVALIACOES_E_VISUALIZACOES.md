# Alterações — avaliações, visualizações únicas e destaques

## Visualizações
- Cada cliente autenticado pode gerar no máximo uma visualização por oferta e uma por destaque.
- A restrição única é aplicada no banco, evitando duplicidade mesmo com aberturas repetidas ou simultâneas.
- A Home consulta os destaques já vistos e os ordena depois dos não vistos; a borda fica cinza para vistos e verde para não vistos.
- Registros antigos, feitos antes da identificação do cliente, permanecem na contagem histórica. A regra de unicidade vale para novos registros.

## Avaliações de empresas
- Avaliações de 1 a 5 estrelas, uma por cliente e empresa.
- O banco só aceita avaliação de perfil `customer` com conta de fidelidade ativa (`left_at IS NULL`).
- A restrição `UNIQUE(company_id, customer_id)` impede uma segunda avaliação, inclusive depois de sair e entrar novamente na fidelidade.
- A média e a quantidade de avaliações são disponibilizadas por RPC e exibidas nas telas de descoberta/Home e no perfil da empresa.

## Publicação
Execute a migration `supabase/migrations/20261125000400_unique_views_and_company_ratings.sql` no SQL Editor do Supabase antes de publicar a versão atualizada do app.
