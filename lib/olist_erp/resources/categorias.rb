# frozen_string_literal: true

module OlistErp
  module Resources
    class Categorias < Base
      PATH = "categorias"

      # A árvore inteira de categorias de produto da conta.
      def arvore = client.get("#{PATH}/todas")

      def obter(id) = client.get("#{PATH}/#{id}")

      def criar(descricao:, id_categoria_pai: nil)
        client.post(PATH, { descricao: descricao, idCategoriaPai: id_categoria_pai }.compact)
      end

      # Achata a árvore em pares {id:, descricao:, caminho:} — útil para um
      # select de categoria sem precisar renderizar a hierarquia.
      def achatada(nos = nil, prefixo = [])
        nos = Array(arvore.is_a?(Hash) ? arvore[:itens] || arvore[:categorias] : arvore) if nos.nil?

        Array(nos).flat_map do |no|
          caminho = prefixo + [no[:descricao]]
          filhos = no[:filhos] || no[:subcategorias] || []

          [{ id: no[:id], descricao: no[:descricao], caminho: caminho.join(" > ") }] +
            achatada(filhos, caminho)
        end
      end
    end
  end
end
