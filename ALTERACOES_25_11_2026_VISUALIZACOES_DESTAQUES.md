# Alterações — visualizações e gerenciamento de destaques

## Painel da empresa
- A aba Ofertas exibe o total de visualizações de cada oferta.
- A aba Destaques exibe o total de visualizações de cada destaque.
- Cada destaque possui ação para pré-visualizar a galeria em tela cheia, incluindo o texto abaixo das mídias.
- Cada destaque possui ação para editar texto, mídias e validade.

## Contagem
- Aberturas de ofertas e destaques feitas por clientes são registradas no Supabase.
- O registro não armazena identificadores ou dados pessoais do cliente.
- O acesso aos totais é restrito ao proprietário da empresa.

## Migração obrigatória
Antes de publicar a versão, execute no SQL Editor do Supabase:

`supabase/migrations/20261125000300_publication_view_counts.sql`

A contagem é atualizada ao recarregar a tela de Divulgação da empresa.
