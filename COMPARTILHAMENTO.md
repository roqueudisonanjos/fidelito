# Compartilhamento no Vanty

## Onde compartilhar
- Cliente: botão de compartilhar Vanty no topo da tela inicial.
- Empresa: botão de compartilhar o próprio clube no topo do painel.
- Cliente: botão de compartilhar em cada recompensa exibida na tela inicial e em Explorar empresas.
- Empresa: botão de compartilhar em cada cartão de recompensa do painel.

## Conteúdo compartilhado
- Aplicativo pelo cliente: mensagem curta, link `https://vanty.web.app` e imagem de marca do Vanty (mantido como antes).
- Clube pelo estabelecimento: nome da empresa, convite para entrar no clube e receber ofertas exclusivas, link do Vanty e imagem de perfil/logo da empresa. Se não houver imagem ou ela não puder ser carregada, usa o logotipo do Vanty.
- Recompensa: mensagem atual, nome da empresa, título e benefício, link do Vanty e imagem pública da empresa. Se a imagem não estiver disponível, usa o logotipo do Vanty. O texto de compartilhamento de recompensa permanece inalterado.

## Dependências
O compartilhamento nativo usa `share_plus` e `http` para carregar imagens públicas. Após atualizar o projeto, execute:

```powershell
flutter pub get
flutter analyze
flutter run
```

A imagem de marca usada como fallback está em `assets/images/vanty_logo.png` e é declarada no `pubspec.yaml`.
