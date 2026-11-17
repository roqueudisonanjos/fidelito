# Fidelito — alterações solicitadas em 15/11/2026

## O que foi alterado

### 1. Benefícios na tela inicial do cliente
- Os cards agora exibem o nome da empresa acima do nome do benefício.
- A consulta da tela inicial considera somente programas em que o cliente tem adesão ativa (`loyalty_accounts.left_at IS NULL`).
- Também exige empresa ativa, benefício ativo e período de vigência válido.
- As páginas de fidelidade e de benefícios da empresa também verificam a adesão ativa.

### 2. Sair de um programa de fidelidade
- Na página de detalhes de uma fidelidade existe a ação **“Não quero mais participar deste programa”**.
- Antes de confirmar, o aplicativo avisa que o saldo será perdido.
- Ao confirmar, o Supabase zera os pontos e marca a conta com `left_at`.
- O histórico de transações e os benefícios já resgatados não são apagados.
- A empresa deixa de ver esse cliente como participante ativo e não pode adicionar novos pontos manualmente.
- O cliente pode voltar a participar pela tela Explorar, mas começa novamente com zero pontos.
- Ler QR Code depois de sair não reativa a adesão automaticamente: o cliente precisa entrar novamente pelo aplicativo.

### 3. Ajuda nas telas iniciais
- Foi adicionado um botão de ajuda na tela inicial do cliente e na tela inicial da empresa.
- Cada perfil recebe um tutorial curto com os principais passos de uso.

### 4. Atualização de senha
- A tela Dados cadastrais do cliente e a tela Dados da empresa (perfil do proprietário) têm a seção **Segurança da conta**.
- A pessoa informa a senha atual, a nova senha e a confirmação.
- A atualização usa `auth.updateUser` do Supabase com `currentPassword`; a senha atual é validada pelo Supabase.
- O aplicativo não lê nem grava hashes de senha diretamente.

### 5. Esqueci minha senha
- A tela de login tem a opção **Esqueci minha senha**.
- Ela abre o WhatsApp com a mensagem exata: `Esqueci a minha senha do fidelito. Poderia me ajudar?`
- O número de suporte é configurado pela variável `SUPPORT_WHATSAPP` (DDI + DDD + número, somente dígitos). O número ainda precisa ser informado/configurado pelo responsável pelo Fidelito.

## Configuração do WhatsApp profissional

Use o número no formato internacional, sem `+`, espaços, parênteses ou hífen. Exemplo fictício: `5511999999999`.

Acrescente esta opção aos comandos de execução/publicação já utilizados pelo projeto:

```bash
--dart-define=SUPPORT_WHATSAPP=55DDDNÚMERO
```

Exemplo de execução (mantenha também os dois parâmetros Supabase que seu projeto já usa):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL \
  --dart-define=SUPPORT_WHATSAPP=55DDDNÚMERO
```

Para publicar na web, use os mesmos parâmetros no `flutter build web --release`. Se `SUPPORT_WHATSAPP` estiver vazio, o aplicativo informa que o contato de suporte ainda não foi configurado, em vez de abrir um endereço inválido.

## Migração obrigatória no Supabase

Execute no SQL Editor do Supabase, depois das migrações anteriores:

1. `20261113000100_multi_company_loyalty.sql`
2. `20261114000100_profile_location_and_manual_points.sql`
3. `20261115000100_membership_exit_password_help.sql`

A terceira migração:
- cria `loyalty_accounts.left_at`;
- cria a função `leave_loyalty_program`;
- atualiza a função de adesão para reativar uma conta sem recuperar pontos;
- impede pontuação, leitura de QR e resgate por uma conta que saiu;
- mantém o histórico de transações e resgates.

Faça backup e teste em um projeto de homologação antes de executar em produção. A migração é transacional e não apaga as contas existentes.

## Procedimento seguro para recuperar senha pelo WhatsApp

1. Peça o e-mail usado no cadastro e confirme que o pedido vem do número de WhatsApp que já está cadastrado no perfil. Se o número não estiver cadastrado ou houver divergência, não altere a senha apenas com base na conversa: faça uma verificação adicional por um canal que já pertença ao titular.
2. Nunca peça a senha antiga, a nova senha, códigos de autenticação ou tokens pelo WhatsApp.
3. Localize o usuário em **Supabase Dashboard → Authentication → Users** e confira cuidadosamente o e-mail e o UUID antes de qualquer alteração.
4. Para uma redefinição manual, gere uma senha temporária aleatória e altere-a pela Auth Admin API em um ambiente de servidor confiável. Exemplo conceitual em JavaScript/Node, executado somente no servidor:

```javascript
const { data, error } = await supabaseAdmin.auth.admin.updateUserById(
  userId,
  { password: temporaryPassword }
);
if (error) throw error;
```

5. `supabaseAdmin` deve ser criado no servidor com a chave secreta/`service_role`, nunca no Flutter, navegador, aplicativo móvel, repositório público ou arquivo de configuração distribuído.
6. Envie a senha temporária somente ao contato verificado. Oriente o usuário a entrar e alterá-la imediatamente em **Dados cadastrais → Segurança da conta**. Não reutilize senhas temporárias.
7. Registre apenas que o atendimento foi concluído; não registre nem armazene a senha temporária.

Não tente atualizar `auth.users.encrypted_password` com SQL: o Supabase gerencia o hash de senha. A Auth Admin API é uma operação privilegiada e deve ficar exclusivamente em servidor seguro. A documentação oficial informa que `updateUserById` é operação server-side e que a chave secreta não pode ser exposta no cliente.

## Validação sugerida

Depois de configurar o número e executar a migração:

```bash
flutter pub get
flutter analyze
flutter test
```

Teste manualmente:
1. Entre com um cliente que participa de duas empresas e confirme que a tela inicial mostra benefícios apenas dessas duas empresas, com o nome correto de cada uma.
2. Saia de uma fidelidade e confirme que ela desaparece de Minhas fidelidades e que os benefícios dessa empresa deixam de aparecer na tela inicial.
3. Confirme que o saldo daquela empresa foi zerado, mas que o histórico antigo e os benefícios já resgatados continuam registrados.
4. Tente ler um QR Code dessa empresa depois de sair: a operação deve ser recusada. Entre novamente em Explorar e confirme que o saldo começa em zero.
5. Confirme que a empresa não consegue adicionar pontos manualmente a quem saiu.
6. Abra Ajuda nas duas telas iniciais.
7. Atualize a senha com a senha atual correta e depois tente com uma senha atual incorreta.
8. Na tela de login, teste Esqueci minha senha e confira se o WhatsApp abre com a mensagem correta.
