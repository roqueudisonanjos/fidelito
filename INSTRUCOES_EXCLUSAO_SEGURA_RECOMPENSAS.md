# Exclusão segura de recompensas

A exclusão de uma recompensa agora é lógica para preservar o histórico de resgates.

## O que muda

- A recompensa recebe `active = false` e `deleted_at = now()`.
- O registro em `promotions` não é apagado fisicamente.
- Registros de `promotion_redemptions` continuam íntegros, pois a chave estrangeira permanece válida.
- Recompensas excluídas deixam de aparecer nas listas de clientes, na gestão da empresa e nos indicadores de recompensas.
- A RPC valida que a recompensa pertence à empresa do usuário autenticado.

## Atualização obrigatória do Supabase

Antes de usar a nova versão do aplicativo, execute no SQL Editor do Supabase o conteúdo de:

`supabase/migrations/20261117000200_soft_delete_promotions.sql`

A migration adiciona `promotions.deleted_at` e cria a função `public.delete_promotion(uuid)`.
Não apague manualmente linhas de `promotion_redemptions` nem altere a chave estrangeira para `ON DELETE CASCADE`.

## Teste recomendado

1. Crie uma recompensa de teste e exclua-a sem resgates.
2. Confirme que ela desapareceu das listagens.
3. Crie outra recompensa, faça um resgate como cliente e depois exclua-a.
4. Confirme que o histórico do cliente e o histórico da empresa continuam mostrando o resgate.
5. Confirme que o código antigo não pode ser validado/resgatado novamente.
