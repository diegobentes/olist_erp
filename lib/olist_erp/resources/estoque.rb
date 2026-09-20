# frozen_string_literal: true

module OlistErp
  module Resources
    # Saldo e lançamentos de estoque.
    class Estoque < Base
      PATH = "estoque"

      BALANCO = "B"
      ENTRADA = "E"
      SAIDA = "S"

      # Devolve saldo, reservado, disponível e a quebra por depósito.
      def obter(id_produto) = client.get("#{PATH}/#{id_produto}")

      # Lançamento de estoque. +tipo+ é B (balanço), E (entrada) ou S (saída).
      # O balanço é o que interessa para sincronizar: ele *define* o saldo em
      # vez de somar, então é idempotente.
      def lancar(id_produto, tipo:, quantidade:, preco_unitario:, deposito_id: nil, data: nil, observacoes: nil)
        payload = {
          tipo: tipo,
          quantidade: quantidade,
          precoUnitario: preco_unitario,
          data: data,
          observacoes: observacoes
        }.compact

        payload[:deposito] = { id: deposito_id } if deposito_id

        client.post("#{PATH}/#{id_produto}", payload)
      end

      def balanco(id_produto, quantidade:, preco_unitario:, **)
        lancar(id_produto, tipo: BALANCO, quantidade: quantidade, preco_unitario: preco_unitario, **)
      end

      def entrada(id_produto, quantidade:, preco_unitario:, **)
        lancar(id_produto, tipo: ENTRADA, quantidade: quantidade, preco_unitario: preco_unitario, **)
      end

      def saida(id_produto, quantidade:, preco_unitario:, **)
        lancar(id_produto, tipo: SAIDA, quantidade: quantidade, preco_unitario: preco_unitario, **)
      end
    end
  end
end
