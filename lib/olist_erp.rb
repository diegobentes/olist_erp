# frozen_string_literal: true

require_relative "olist_erp/version"
require_relative "olist_erp/errors"
require_relative "olist_erp/token"
require_relative "olist_erp/rate_limit"
require_relative "olist_erp/page"
require_relative "olist_erp/oauth"
require_relative "olist_erp/client"
require_relative "olist_erp/resources/base"
require_relative "olist_erp/resources/produtos"
require_relative "olist_erp/resources/estoque"
require_relative "olist_erp/resources/categorias"
require_relative "olist_erp/resources/marcas"
require_relative "olist_erp/resources/depositos"
require_relative "olist_erp/resources/listas_de_precos"
require_relative "olist_erp/resources/empresa"

# Cliente Ruby para a API v3 do ERP da Olist (ex-Tiny).
#
#   oauth = OlistErp::OAuth.new(client_id: ..., client_secret: ..., redirect_uri: ...)
#   redirect_to oauth.authorize_url(state: conta.id)
#   token = oauth.exchange_code(params[:code])
#
#   client = OlistErp::Client.new(access_token: token.access_token)
#   client.produtos.criar(sku: "CAM-001", descricao: "Camiseta", tipo: "S")
#
# A gem não guarda estado nem assume Rails: quem persiste token é a aplicação.
module OlistErp
  module Resources; end
end
