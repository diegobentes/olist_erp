# frozen_string_literal: true

module OlistErp
  # Fotografia dos headers X-RateLimit-* da última resposta.
  #
  # Vale lembrar que o limite é por conta do ERP, não por aplicativo: se a conta
  # tiver outros apps ativos, todos dividem o mesmo balde.
  class RateLimit
    attr_reader :limit, :remaining, :reset_in

    def initialize(limit: nil, remaining: nil, reset_in: nil)
      @limit = limit
      @remaining = remaining
      @reset_in = reset_in
    end

    def self.from_headers(headers)
      return new if headers.nil?

      new(
        limit: integer_or_nil(headers["x-ratelimit-limit"]),
        remaining: integer_or_nil(headers["x-ratelimit-remaining"]),
        reset_in: integer_or_nil(headers["x-ratelimit-reset"])
      )
    end

    def self.integer_or_nil(value)
      return nil if value.nil? || value.to_s.strip.empty?

      Integer(value.to_s.strip, exception: false)
    end
    private_class_method :integer_or_nil

    def exhausted?
      !remaining.nil? && remaining <= 0
    end

    def to_h
      { limit: limit, remaining: remaining, reset_in: reset_in }
    end
  end
end
