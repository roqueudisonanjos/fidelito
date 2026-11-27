# Configuração e publicação do Plim

## Supabase

O projeto continua usando o mesmo projeto Supabase. A aplicação lê as credenciais em tempo de compilação por meio de `--dart-define`; não coloque a chave privada `service_role` no aplicativo.

No PowerShell, gere a versão web informando a URL e a chave pública (Publishable Key ou anon key):

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://exnjjkmkwupkettuarjk.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

Se `SUPABASE_URL` ou `SUPABASE_PUBLISHABLE_KEY` forem omitidas, o aplicativo exibirá “Supabase não configurado”. Essas credenciais não estavam armazenadas no ZIP recebido, portanto não foram inventadas nem embutidas.

## Destaques

Antes de publicar, execute no SQL Editor do Supabase o arquivo:

`supabase/migrations/20261125_create_company_stories.sql`

Os arquivos de mídia são enviados para o bucket já utilizado pelo aplicativo (`fidelito-images`), na pasta `stories/`. Não é necessário renomear o bucket para a funcionalidade operar.

## Publicação

Depois de executar a migration e compilar com as variáveis acima, publique a pasta `build/web` no Firebase Hosting como já faz atualmente.
