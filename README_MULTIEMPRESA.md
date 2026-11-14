# Atualização multiempresa do Fidelito

Esta entrega adiciona a descoberta de empresas por cidade, adesão a programas de fidelidade e consulta individual de saldo, benefícios e histórico por empresa.

Leia `MIGRACAO_E_TESTES.md` antes de implantar. O SQL está em `supabase/migrations/20261113000100_multi_company_loyalty.sql`.

**Importante:** a migração SQL ainda precisa ser executada manualmente no Supabase, primeiro em ambiente de teste. Nenhuma alteração foi aplicada ao banco de produção. O diretório `build/`, arquivos locais de configuração e o diretório temporário `supabase/.temp/` foram excluídos do ZIP para evitar artefatos grandes e dados de vinculação local; os arquivos de código e configuração do projeto foram preservados.


## Atualização adicional (14/11/2026)

- Menu inferior do cliente com ícones e botão central de QR Code.
- Removido o cartão de total de pontos da tela inicial.
- Cidade/UF no perfil do cliente, com preenchimento manual ou pela localização do dispositivo.
- Explorar usa a cidade/UF do perfil ou tenta obter a localização com permissão; também mostra promoções ativas.
- Empresa pode adicionar pontos manualmente na tela Meus clientes.
- Execute também `20261114000100_profile_location_and_manual_points.sql` no Supabase.
