# olist_erp

Cliente Ruby para a **API v3 do ERP da Olist** (ex-Tiny ERP): OAuth 2, produtos,
estoque, preços, categorias, marcas, depósitos e listas de preço.

A gem é propositalmente sem estado e sem Rails: ela fala HTTP e devolve `Hash`
com chaves simbolizadas. Quem decide onde guardar token é a sua aplicação — o
que torna natural operar **várias contas do ERP** com o mesmo processo.

> Para a API v2 (`api2.tiny.com.br`, autenticação por token fixo) esta gem não
> serve. A v2 continua no ar, mas está congelada: não recebe recursos novos.

## Instalação

```ruby
gem "olist_erp", github: "diegobentes/olist_erp"
```

## Autenticação

O ERP usa OAuth 2 (authorization code) num Keycloak. As credenciais do
aplicativo (`client_id` / `client_secret`) saem do módulo de integrações da
conta do ERP.

```ruby
oauth = OlistErp::OAuth.new(
  client_id: ENV["OLIST_CLIENT_ID"],
  client_secret: ENV["OLIST_CLIENT_SECRET"],
  redirect_uri: "https://seuapp.com/olist/callback"
)

# 1. Mande a pessoa para o consentimento.
redirect_to oauth.authorize_url(state: conta.id)

# 2. No callback, troque o código pelos tokens.
token = oauth.exchange_code(params[:code])
token.access_token   # usar nas chamadas
token.refresh_token  # guardar para renovar
token.expires_at     # ~4 horas
```

### Validade dos tokens

| token | validade |
|---|---|
| access token | ~4 horas |
| refresh token | ~24 horas |

O refresh token vale **um dia**. Isso significa que uma aplicação que fique 24h
sem renovar perde a autorização e precisa de novo consentimento da pessoa. O
jeito de evitar isso é renovar por agendamento, não só sob demanda:

```ruby
# roda de hora em hora
token = oauth.refresh(conta.refresh_token)
conta.update!(
  access_token: token.access_token,
  refresh_token: token.refresh_token, # o Keycloak rotaciona: guarde o novo
  expires_at: token.expires_at
)
```

`Token#expiring_soon?` existe justamente para esse job:

```ruby
token.expiring_soon?          # menos de 1h de access token
token.expired?                # já vencido (com 60s de folga)
token.refresh_expired?        # perdeu a autorização: refazer o consentimento
```

## Uso

```ruby
client = OlistErp::Client.new(access_token: conta.access_token)
```

Em aplicações de verdade, prefira o bloco: ele é avaliado a cada chamada, então
a renovação acontece sem o client precisar ser reconstruído.

```ruby
client = OlistErp::Client.new { conta.access_token_valido! }
```

### Produtos

```ruby
client.produtos.criar(
  sku: "CAM-001",
  descricao: "Camiseta Algodão Pima",
  tipo: "S",                      # S simples, V variações, K kit, F fabricado, M matéria-prima
  unidade: "UN",
  ncm: "61091000",
  gtin: "7891234567890",
  marca: { id: 12 },
  categoria: { id: 340 },
  precos: { preco: 129.90, precoCusto: 48.00 },
  dimensoes: { pesoLiquido: 0.18, pesoBruto: 0.22, largura: 30, altura: 2, comprimento: 40 },
  estoque: { controlar: true, inicial: 25, minimo: 5 },
  seo: {
    titulo: "Camiseta Algodão Pima Masculina",
    descricao: "Camiseta em algodão pima peruano, toque macio e caimento reto.",
    keywords: ["camiseta algodão pima", "camiseta premium"],
    linkVideo: "https://youtube.com/watch?v=xyz",
    slug: "camiseta-algodao-pima"
  },
  anexos: [{ url: "https://cdn.exemplo.com/cam-001-1.jpg", externo: true }]
)
```

O objeto `seo` é nativo da API: título, descrição, palavras-chave, **link de
vídeo** e slug vão para o ERP e seguem dele para os canais de venda.

```ruby
client.produtos.obter(55)
client.produtos.obter_por_sku("CAM-001")
client.produtos.atualizar(55, descricao: "Camiseta Algodão Pima (nova safra)")
client.produtos.atualizar_preco(55, preco: 139.90, preco_custo: 48.00)

client.produtos.adicionar_anexos(55, [{ url: "https://cdn.exemplo.com/2.jpg", externo: true }])
```

### Listagem e paginação

```ruby
pagina = client.produtos.listar(nomeProduto: "camiseta", limit: 50)
pagina.itens
pagina.total
pagina.last_page?

# Enumerator preguiçoso sobre todas as páginas:
client.produtos.todos(situacao: "A").each { |produto| ... }
client.produtos.todos.lazy.first(200)
```

Cuidado com catálogos grandes: cada página é uma chamada, e o limite de
requisições é **por conta do ERP** — se a conta tiver outros aplicativos
ativos, todos dividem o mesmo balde.

### Estoque

```ruby
client.estoque.obter(55)
# => { id: 55, saldo: 10.0, reservado: 2.0, disponivel: 8.0, depositos: [...] }

# Balanço DEFINE o saldo (idempotente) — é o que usar para sincronizar.
client.estoque.balanco(55, quantidade: 12, preco_unitario: 48.00, deposito_id: 7)

# Entrada e saída SOMAM e SUBTRAEM.
client.estoque.entrada(55, quantidade: 10, preco_unitario: 48.00)
client.estoque.saida(55, quantidade: 3, preco_unitario: 48.00)
```

### Outros recursos

```ruby
client.categorias.arvore
client.categorias.achatada              # [{ id:, descricao:, caminho: "Roupas > Camisetas" }]
client.marcas.encontrar_ou_criar("Pima Co")
client.depositos.todos.to_a
client.listas_de_precos.todas.to_a
client.empresa.info                      # dados da conta conectada
```

## Limite de requisições

Os headers `X-RateLimit-*` de cada resposta ficam acessíveis:

```ruby
client.last_rate_limit.to_h   # { limit: 120, remaining: 98, reset_in: 42 }
client.last_rate_limit.exhausted?
```

Em `429` o client espera o `X-RateLimit-Reset` e repete; em `5xx` repete com
espera crescente. Erros definitivos (`400`, `401`, `403`, `404`) **não** são
repetidos — insistir devolveria o mesmo erro e só queimaria o limite da conta.
O teto de tentativas é configurável:

```ruby
OlistErp::Client.new(access_token: t, max_retries: 5, timeout: 45)
```

## Erros

Todos descendem de `OlistErp::Error`.

| classe | quando |
|---|---|
| `OlistErp::ConfigurationError` | faltou `client_id`, `access_token`, `redirect_uri`… |
| `OlistErp::ValidationError` | `400` — payload recusado pelo ERP |
| `OlistErp::AuthenticationError` | `401` e falhas de OAuth |
| `OlistErp::ForbiddenError` | `403` — aplicativo sem permissão no recurso |
| `OlistErp::NotFoundError` | `404` |
| `OlistErp::RateLimitError` | `429` depois de esgotadas as tentativas |
| `OlistErp::ServerError` | `5xx` |

O erro de validação já vem com os campos desempacotados:

```ruby
begin
  client.produtos.criar(descricao: "sem sku")
rescue OlistErp::ValidationError => e
  e.status               # 400
  e.mensagens_de_campo   # ["sku: O campo sku é obrigatório"]
  e.body                 # corpo cru, se precisar
end
```

## Desenvolvimento

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

As specs usam WebMock: nenhuma chamada real à API.

## Licença

MIT. Veja [LICENSE.txt](LICENSE.txt).
