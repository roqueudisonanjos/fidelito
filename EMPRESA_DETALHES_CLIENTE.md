# Detalhes das empresas para clientes

## O que mudou

- Os cards de benefícios da tela inicial do cliente abrem a tela pública de detalhes da empresa responsável pelo benefício.
- Os cards de empresas em Explorar abrem a mesma tela.
- Os cards em Minhas fidelidades também abrem os detalhes da empresa.
- A tela apresenta nome, logotipo (quando cadastrado), descrição, WhatsApp, endereço, cidade e UF.
- O telefone pode ser aberto diretamente no WhatsApp.
- Para empresas das quais o cliente participa, há um botão para abrir a tela da fidelidade e consultar pontos, benefícios e histórico.
- Se o cliente sair da fidelidade a partir dessa tela, a navegação retorna corretamente e as listas anteriores são atualizadas.

## Banco de dados

Não é necessária nova migração. A implementação consulta os campos públicos já existentes em `public.companies`: `id`, `name`, `description`, `phone`, `address`, `city`, `state`, `logo_url` e `active`.

## Arquivos principais

- `lib/pages/customer/company_details_page.dart`
- `lib/services/loyalty_program_service.dart`
- `lib/pages/customer/customer_home_page.dart`
- `lib/pages/customer/explore_page.dart`
- `lib/pages/customer/my_loyalty_programs_page.dart`
- `lib/core/router/app_router.dart`
