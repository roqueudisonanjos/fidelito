# Atualizações do Vanty — 17/11/2026

## Alterações

1. A empresa agora pode editar recompensas já cadastradas. O formulário é preenchido com os dados atuais e permite alterar título, descrição, imagem, tipo, pontos necessários, desconto/brinde e datas. A gravação usa `PromotionService.updatePromotion`, filtrando pelo ID da recompensa e pelo ID da empresa.
2. Em **Minhas fidelidades**, tocar em uma empresa abre diretamente a tela de fidelidade do cliente (saldo, recompensas e histórico). Nessa tela foi incluído o botão **Ver empresa**, que abre os detalhes da empresa.
3. Foi adicionado espaçamento inferior entre os cartões de **Recompensas disponíveis** na tela da fidelidade.
4. Foi incluído o botão **Atualizar** na barra superior da tela inicial do cliente, ao lado do botão de suporte. Ele executa o mesmo `loadData` usado para atualizar a tela.

## Banco de dados

Não é necessária nova migração SQL para estas alterações. A edição utiliza a tabela `promotions` e a operação `UPDATE` já existente no serviço; as permissões RLS atuais da empresa devem permitir a atualização das próprias recompensas.

## Verificação

O ZIP foi recriado e validado com `unzip -t`. O ambiente de edição não possui Flutter/Dart instalado, portanto não foi possível executar `dart format`, `flutter analyze` ou testes Flutter. Recomenda-se executar esses comandos localmente após extrair o projeto.
