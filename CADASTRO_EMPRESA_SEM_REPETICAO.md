# Cadastro de empresa sem repetir nome e WhatsApp

Ao escolher o tipo de conta **Empresa**, o cadastro inicial identifica os campos como nome e WhatsApp do responsável.

Quando o responsável chega à tela de cadastro da empresa, os campos **Nome da empresa** e **WhatsApp comercial** são preenchidos automaticamente com os dados já informados na criação da conta, usando primeiro o perfil do Supabase e, como alternativa, os metadados do usuário autenticado.

Os dois campos permanecem editáveis. Assim, se o nome comercial ou o WhatsApp da empresa forem diferentes dos dados do responsável, basta alterar o campo correspondente. Não é necessário preencher novamente os mesmos dados.

Não foi necessária migração SQL. A alteração utiliza `profiles.full_name`, `profiles.whatsapp` e os metadados `full_name`/`phone` já enviados durante o cadastro.
