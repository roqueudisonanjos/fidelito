# Fidelito — alterações de interface e fidelidade (14/11/2026)

## O que mudou

- Removido da tela inicial do cliente o cartão com a soma dos pontos de todas as fidelidades.
- As ações do cliente foram movidas para um menu inferior somente com ícones; o botão de escanear QR Code fica centralizado.
- Explorar empresas usa primeiro cidade/UF cadastradas no perfil. Se não houver cidade salva, tenta solicitar a localização do dispositivo e identificar cidade/UF automaticamente. Se a permissão não for concedida, a busca manual continua disponível.
- Dados cadastrais do cliente agora permitem editar cidade e UF ou preencher esses campos pela localização do dispositivo.
- Explorar empresas também lista promoções e descontos ativos e dentro do período de validade.
- Na tela de clientes da empresa, foi adicionado o botão **Adicionar pontos manualmente**. A operação registra uma transação `earn` e atualiza o saldo sem QR Code.

## Implantação

1. Faça backup do Supabase.
2. No SQL Editor do Supabase, execute `20261114000100_profile_location_and_manual_points.sql`.
3. Na pasta do projeto, execute `flutter pub get` para instalar `geolocator` e `http`.
4. Execute o app como já fazia, passando `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`.
5. Teste primeiro com contas de teste: salvar cidade/UF, permitir e negar localização, explorar empresas e promoções, e adicionar pontos manualmente.

A migração anterior de multiempresa não precisa ser reaplicada se já foi executada. Este arquivo é uma migração adicional.

## Observações importantes

- A localização automática depende da permissão do navegador/dispositivo. No Flutter Web, use `localhost` ou HTTPS e permita a localização no navegador.
- A identificação do endereço aproximado usa o serviço de geocodificação reversa do OpenStreetMap/Nominatim. Se o serviço não responder, a pessoa pode digitar cidade e UF.
- A pontuação manual está disponível para clientes que já possuem conta de fidelidade naquela empresa. A função SQL valida o proprietário da empresa, a participação do cliente e a quantidade de pontos; o cliente não pode ser pontuado em outra empresa.
- Não foi usada chave `service_role` no aplicativo.
- Este ambiente não possui Flutter/Dart instalado; por isso não foi possível executar `flutter analyze` nem compilar a aplicação aqui. Depois de `flutter pub get`, rode `flutter analyze` e teste no navegador/dispositivo antes de publicar.
