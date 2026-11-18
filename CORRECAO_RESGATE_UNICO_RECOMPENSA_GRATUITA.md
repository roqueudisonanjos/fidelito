# Correção: resgate único de recompensa gratuita

A migration `supabase/migrations/20261118000100_enforce_single_free_reward_redemption.sql` adiciona uma proteção no banco de dados para que cada cliente possa resgatar uma única vez cada recompensa cujo `points_required` seja `0`.

A proteção é aplicada por trigger `BEFORE INSERT` na tabela `promotion_redemptions`. O trigger bloqueia a linha da promoção (`FOR UPDATE`) antes de verificar resgates anteriores, evitando que duas tentativas simultâneas passem pela verificação. A regra vale também para inserções que não utilizem a RPC `redeem_promotion`.

Resgates anteriores são preservados. A migration não apaga nem altera o histórico.

## Aplicação

No Supabase, abra **SQL Editor**, cole o conteúdo da migration e execute. Depois, teste com o mesmo cliente:

1. Resgatar uma recompensa gratuita ainda não resgatada: deve funcionar.
2. Tentar resgatar novamente a mesma recompensa: deve ser recusado com a mensagem de que ela já foi resgatada.
3. Resgatar outra recompensa gratuita: deve funcionar uma vez.
4. Resgatar uma recompensa que exige pontos: continua seguindo as regras normais de pontos.

Importante: incluir uma migration no ZIP não a executa automaticamente no projeto Supabase. A regra só passa a valer depois da execução no SQL Editor (ou pelo fluxo de migrations utilizado no projeto).
