# frozen_string_literal: true

module OlistErp
  module Resources
    class Base
      MAX_LIMIT = 100

      def initialize(client)
        @client = client
      end

      private

      attr_reader :client

      # Percorre um endpoint paginado devolvendo Page por Page.
      def each_page(path, params = {}, limit: MAX_LIMIT)
        return to_enum(:each_page, path, params, limit: limit) unless block_given?

        offset = params[:offset].to_i
        loop do
          page = Page.from_payload(client.get(path, params.merge(limit: limit, offset: offset)) || {})
          yield page

          offset = page.next_offset
          break if offset.nil?
        end
      end

      # Achata a paginação em um Enumerator de itens. Cuidado com catálogos
      # grandes: cada página é uma chamada e o limite da API é por conta.
      def each_item(path, params = {}, limit: MAX_LIMIT, &block)
        return to_enum(:each_item, path, params, limit: limit) unless block_given?

        each_page(path, params, limit: limit) { |page| page.each(&block) }
      end
    end
  end
end
