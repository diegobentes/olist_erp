# frozen_string_literal: true

module OlistErp
  module Resources
    # Listas de preço — é por aqui que se mantém um preço diferente por canal
    # dentro do próprio ERP.
    class ListasDePrecos < Base
      PATH = "listas-precos"

      def listar(limit: MAX_LIMIT, offset: 0, **filtros)
        Page.from_payload(client.get(PATH, filtros.merge(limit: limit, offset: offset)) || {})
      end

      def todas(limit: MAX_LIMIT, **filtros, &) = each_item(PATH, filtros, limit: limit, &)

      def obter(id) = client.get("#{PATH}/#{id}")

      def criar(payload) = client.post(PATH, payload)

      def atualizar(id, payload) = client.put("#{PATH}/#{id}", payload)
    end
  end
end
