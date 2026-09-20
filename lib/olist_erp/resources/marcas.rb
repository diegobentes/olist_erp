# frozen_string_literal: true

module OlistErp
  module Resources
    class Marcas < Base
      PATH = "marcas"

      def listar(limit: MAX_LIMIT, offset: 0, **filtros)
        Page.from_payload(client.get(PATH, filtros.merge(limit: limit, offset: offset)) || {})
      end

      def todas(limit: MAX_LIMIT, **filtros, &) = each_item(PATH, filtros, limit: limit, &)

      def criar(nome:) = client.post(PATH, { nome: nome })

      def atualizar(id, nome:) = client.put("#{PATH}/#{id}", { nome: nome })

      # Acha a marca pelo nome ou cria — evita duplicar marca a cada produto novo.
      def encontrar_ou_criar(nome)
        existente = todas(nome: nome).find { |marca| marca[:nome].to_s.casecmp?(nome.to_s) }
        return existente if existente

        criar(nome: nome)
      end
    end
  end
end
