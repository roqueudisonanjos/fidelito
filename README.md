# Fidelito

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
