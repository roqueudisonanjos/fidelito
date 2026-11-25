# Vanty

Projeto Flutter com Supabase.

## Executar localmente

```bash
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 5000 \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

Use somente a chave pública `publishable` (ou a antiga `anon`) no aplicativo. Nunca use `service_role` ou chave `secret` no cliente.

## Migrações

- `20261113000100_multi_company_loyalty.sql`: migração multiempresa (execute primeiro se ainda não foi aplicada).
- `20261114000100_profile_location_and_manual_points.sql`: adiciona cidade/UF ao perfil, grants de atualização necessários e RPC segura para pontuação manual (execute depois).

Veja `ALTERACOES_14_11_2026.md` para detalhes e roteiro de testes.

## Painel administrativo

A versão inclui o painel administrativo e a Edge Function `admin-console`. Consulte `PAINEL_ADMINISTRATIVO.md` para criar o primeiro administrador, aplicar a migração, implantar a função e configurar os links de recuperação do Supabase Auth.


## Atualização 16/11/2026 — contas e imagens

Execute no SQL Editor do Supabase a migração `supabase/migrations/20261116000200_profiles_and_reward_images_account_rules.sql`. Em seguida, na pasta do Flutter, execute `flutter pub get` (nova dependência `image_picker`), `flutter analyze` e `flutter test`. A migração adiciona `profiles.avatar_url`, `promotions.image_url`, configura o bucket `fidelito-images` e exige que a empresa esteja desativada antes da exclusão definitiva.


## Hospedagem Web Vanty

O site Firebase Hosting está configurado para o ID `vanty` (`https://vanty.web.app`). Consulte `CONFIGURAR_DOMINIO_VANTY.md` para criar o site de Hosting, atualizar URLs de retorno do Supabase e publicar.

Para gerar uma versão release:
flutter build web --release --dart-define=SUPPORT_WHATSAPP=55DDDNÚMERO --dart-define=SUPABASE_PUBLISHABLE_KEY=KEY_SUPABASE --dart-define=SUPABASE_URL=URLSUPABASE