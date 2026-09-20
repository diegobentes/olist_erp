# frozen_string_literal: true

module OlistErp
  # Uma página de um endpoint de listagem: +itens+ mais a +paginacao+ do ERP.
  class Page
    include Enumerable

    attr_reader :itens, :limit, :offset, :total

    def initialize(itens:, limit: nil, offset: nil, total: nil)
      @itens = itens
      @limit = limit
      @offset = offset
      @total = total
    end

    def self.from_payload(payload)
      paginacao = payload[:paginacao] || {}

      new(
        itens: Array(payload[:itens]),
        limit: paginacao[:limit],
        offset: paginacao[:offset],
        total: paginacao[:total]
      )
    end

    def each(&) = itens.each(&)

    def size = itens.size

    def empty? = itens.empty?

    # Offset da próxima página, ou nil quando a listagem acabou.
    def next_offset
      return nil if limit.nil? || offset.nil?
      return nil if itens.empty?

      following = offset + limit
      return nil if total && following >= total

      following
    end

    def last_page? = next_offset.nil?
  end
end
