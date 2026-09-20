# frozen_string_literal: true

module OlistErp
  module Resources
    class Depositos < Base
      PATH = "depositos"

      def listar(limit: MAX_LIMIT, offset: 0, **filtros)
        Page.from_payload(client.get(PATH, filtros.merge(limit: limit, offset: offset)) || {})
      end

      def todos(limit: MAX_LIMIT, **filtros, &) = each_item(PATH, filtros, limit: limit, &)

      def obter(id) = client.get("#{PATH}/#{id}")
    end
  end
end
