# Fidelito — atualização multiempresa

## O que foi alterado no aplicativo

- Nova tela **Explorar empresas**, com busca por cidade e nome.
- Nova tela **Minhas fidelidades**, que lista apenas programas nos quais o cliente possui conta.
- Nova tela de detalhes de cada fidelidade, com saldo, benefícios e histórico separados por empresa.
- Adesão explícita pelo botão **Participar da fidelidade**.
- O escaneamento de QR Code continua criando a conta automaticamente quando ela ainda não existe, preservando o fluxo anterior.
- O total exibido na tela inicial é a soma dos saldos das fidelidades do cliente; os detalhes mostram o saldo individual de cada empresa.
- O cadastro/edição da empresa agora inclui cidade e UF.
- A lista de benefícios da tela inicial passa a considerar somente empresas nas quais o cliente já participa.

## Ordem de implantação

1. Faça backup do projeto Supabase e teste em um projeto de desenvolvimento.
2. Abra o SQL Editor do Supabase.
3. Execute integralmente `supabase/migrations/20261113000100_multi_company_loyalty.sql`.
4. Publique a nova versão Flutter.
5. Edite os dados da empresa existente e preencha cidade e UF. A migração não altera nem remove os dados antigos.
6. Verifique se a empresa está `active = true`; somente empresas ativas aparecem na descoberta.

A migração mantém a função antiga `create_company` de quatro parâmetros por compatibilidade e adiciona a versão de seis parâmetros usada pelo novo aplicativo. Não apaga contas, pontos, transações, promoções ou resgates.

## Testes recomendados

Use dois usuários clientes e duas empresas ativas diferentes.

1. **Descoberta:** cliente A pesquisa uma cidade e vê somente empresas ativas correspondentes.
2. **Adesão:** cliente A entra no programa da empresa 1; uma linha é criada em `loyalty_accounts` com saldo inicial zero.
3. **Idempotência:** cliente A clica novamente/repete a adesão; a mesma conta e o mesmo saldo são mantidos.
4. **Isolamento:** cliente A não vê a fidelidade da empresa 2 em Minhas fidelidades antes de entrar nela.
5. **Saldo separado:** ao pontuar na empresa 1, o saldo da empresa 2 não muda.
6. **Histórico separado:** a página da empresa 1 não mostra transações da empresa 2.
7. **QR Code:** escanear um QR de empresa ativa cria a conta se necessário e credita pontos uma única vez; reutilizar o QR deve falhar.
8. **Resgate:** resgatar benefício debita pontos somente da conta da empresa da promoção e registra a transação/resgate nessa empresa.
9. **Empresa inativa:** uma empresa inativa não aparece na descoberta, não aceita adesão e não aceita resgate/QR.
10. **Dados antigos:** compare saldos e quantidade de linhas de `loyalty_accounts`, `loyalty_transactions` e `promotion_redemptions` antes/depois da implantação.

## Observações de segurança

- O isolamento dos dados continua dependendo das políticas RLS existentes nas tabelas; filtros no Flutter não são uma barreira de segurança.
- A função `join_loyalty_program` é `SECURITY DEFINER`, valida sessão, perfil de cliente, empresa ativa e impede adesão do proprietário à própria empresa.
- `redeem_promotion` valida adesão e empresa ativa antes de debitar pontos.
- `redeem_qr_code` valida QR, empresa ativa e impede uso pelo proprietário; `earn_points` agora delega a esse fluxo para impedir reutilização de QR.
- `validate_promotion_redemption` e `use_promotion_redemption` passam a bloquear concorrência com bloqueio de linha e só permitem validação pelo proprietário da empresa ativa, preservando a regra atual.
- O SQL fornecido na conversa não incluía a definição textual completa de todas as políticas RLS. Por isso, a migração preserva as políticas existentes e acrescenta somente a política de descoberta de empresas ativas; não remove políticas antigas.

## Limitação de validação nesta entrega

O ambiente de trabalho não possui Flutter/Dart instalado e não há credenciais para conectar ao Supabase. Portanto, não foi possível executar `flutter analyze`, compilar o app ou testar as funções no banco. A migração é um arquivo para revisão e execução pelo responsável do projeto; nada foi aplicado no Supabase de produção.
