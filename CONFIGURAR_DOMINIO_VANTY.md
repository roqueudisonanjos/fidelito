# Configuração de hospedagem Web — Vanty

O projeto Firebase associado continua sendo `susu-35238`. O Firebase Hosting site configurado em `firebase.json` agora é `vanty`, para o endereço `https://vanty.web.app`.

## 1. Criar o site de Hosting (uma única vez)
Na raiz do projeto, com Firebase CLI autenticado:

```bash
firebase hosting:sites:create vanty --project susu-35238
```

Se o site `vanty` já existir no projeto, não execute novamente.

## 2. Configurar o Supabase Auth
No Supabase Dashboard, Authentication → URL Configuration:
- Site URL: `https://vanty.web.app`
- Redirect URLs: inclua `https://vanty.web.app/reset-password`

Atualize o secret usado pela função de administração (se ele estiver configurado para o endereço antigo):
```bash
supabase secrets set FIDELITO_SITE_URL=https://vanty.web.app
```

## 3. Gerar e publicar
Na raiz do projeto:

```bash
flutter build web
firebase deploy --only hosting --project susu-35238
```

O `firebase.json` já aponta para o site de Hosting `vanty`. O deploy só terá sucesso se esse site já tiver sido criado no projeto Firebase.

## 4. Verificação
Após o deploy, teste:
- `https://vanty.web.app`
- Login e recuperação de senha, incluindo o retorno por `/reset-password`
- Compartilhamento de empresas/ofertas/recompensas para confirmar que os links usam o domínio novo.

O domínio antigo `fidelito.web.app` não é automaticamente redirecionado. Mantenha o site antigo durante a transição e configure um redirecionamento separado se desejar.
