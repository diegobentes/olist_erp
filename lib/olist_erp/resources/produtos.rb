# frozen_string_literal: true

module OlistErp
  module Resources
    # Produtos: criação, edição, preço e anexos.
    class Produtos < Base
      PATH = "produtos"

      # Uma página de produtos. Filtros aceitos pela API: nomeProduto,
      # codigoProduto, gtin, situacao, dataCriacao, dataAlteracao, idListaPreco.
      def listar(limit: MAX_LIMIT, offset: 0, **filtros)
        Page.from_payload(client.get(PATH, filtros.merge(limit: limit, offset: offset)) || {})
      end

      def paginas(limit: MAX_LIMIT, **filtros, &) = each_page(PATH, filtros, limit: limit, &)

      def todos(limit: MAX_LIMIT, **filtros, &) = each_item(PATH, filtros, limit: limit, &)

      def obter(id) = client.get("#{PATH}/#{id}")

      # Atalho para achar o produto pelo SKU — a API não tem "obter por SKU",
      # e o filtro por código é "contém", então conferimos a igualdade aqui.
      def obter_por_sku(sku)
        listar(codigoProduto: sku, limit: 50).find { |produto| produto[:sku].to_s == sku.to_s || produto[:codigo].to_s == sku.to_s }
      end

      # +tipo+: S simples, V com variações, K kit, F fabricado, M matéria-prima.
      def criar(payload) = client.post(PATH, payload)

      def atualizar(id, payload) = client.put("#{PATH}/#{id}", payload)

      def atualizar_preco(id, preco: nil, preco_promocional: nil, preco_custo: nil)
        payload = {
          preco: preco,
          precoPromocional: preco_promocional,
          precoCusto: preco_custo
        }.compact

        client.put("#{PATH}/#{id}/preco", payload)
      end

      def anexos(id) = client.get("#{PATH}/#{id}/anexos")

      # +lista+ é um array de { url:, externo: true }.
      def adicionar_anexos(id, lista) = client.post("#{PATH}/#{id}/anexos", Array(lista))

      def substituir_anexos(id, lista) = client.put("#{PATH}/#{id}/anexos", Array(lista))
    end
  end
end
