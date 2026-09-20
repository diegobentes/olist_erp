# Changelog

## [Unreleased]

## [0.1.0] - 2026-09-20

- Primeira versão.
- OAuth 2 (authorization code, refresh e revoke) contra o Keycloak do ERP.
- Cliente HTTP da API v3 com token por conta, headers de limite de requisição,
  repetição automática em 429/5xx e erros tipados.
- Recursos: produtos (incl. preço e anexos), estoque, categorias, marcas,
  depósitos, listas de preço e dados da empresa.
- Paginação automática via `#todos` / `#paginas`.
