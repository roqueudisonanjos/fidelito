# Atualizações de contas, fotos e recompensas

## Exclusão de contas
- Cliente: pode solicitar exclusão definitiva, com confirmação de senha e remoção dos dados de fidelidade.
- Empresa: precisa primeiro ser desativada. Após a suspensão, a tela de empresa suspensa mantém disponível somente o encerramento definitivo da conta, suporte e saída. A função do banco também bloqueia a exclusão enquanto a empresa estiver ativa.

## Imagens
- Cliente: foto de perfil salva em `profiles.avatar_url`.
- Empresa: imagem/logo salva em `companies.logo_url`.
- Recompensa: imagem salva em `promotions.image_url`.
- Arquivos ficam no bucket público `fidelito-images`, com envio restrito à pasta do usuário autenticado. Limite: 5 MB.

## Terminologia
A interface passa a usar “Recompensas” em telas e mensagens antes chamadas de “Benefícios”, sem alterar nomes de tabelas, rotas ou contratos internos do banco.

## Migração obrigatória
Execute `supabase/migrations/20261116000200_profiles_and_reward_images_account_rules.sql` no SQL Editor do Supabase. Depois execute `flutter pub get` para instalar `image_picker`.
