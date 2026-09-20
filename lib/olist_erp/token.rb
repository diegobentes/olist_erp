# frozen_string_literal: true

module OlistErp
  # Par de tokens devolvido pelo Keycloak do ERP.
  #
  # O access token vale ~4h e o refresh token ~1 dia. Como o refresh token morre
  # em 24h, uma aplicação que fica dias sem chamar a API perde a autorização e
  # precisa passar pelo consentimento de novo — daí o +expiring_soon?+, feito
  # para um job periódico renovar antes de chegar nesse ponto.
  class Token
    attr_reader :access_token, :refresh_token, :expires_in, :refresh_expires_in,
                :token_type, :scope, :obtained_at

    def initialize(access_token:, refresh_token: nil, expires_in: nil, refresh_expires_in: nil,
                   token_type: "Bearer", scope: nil, obtained_at: Time.now)
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_in = expires_in
      @refresh_expires_in = refresh_expires_in
      @token_type = token_type
      @scope = scope
      @obtained_at = obtained_at
    end

    def self.from_response(payload, obtained_at: Time.now)
      new(
        access_token: payload[:access_token],
        refresh_token: payload[:refresh_token],
        expires_in: payload[:expires_in],
        refresh_expires_in: payload[:refresh_expires_in],
        token_type: payload[:token_type] || "Bearer",
        scope: payload[:scope],
        obtained_at: obtained_at
      )
    end

    def expires_at
      expires_in && (obtained_at + expires_in)
    end

    def refresh_expires_at
      refresh_expires_in && (obtained_at + refresh_expires_in)
    end

    def expired?(skew: 60)
      return false unless expires_at

      Time.now >= (expires_at - skew)
    end

    # Serve para o agendamento da renovação: por padrão avisa quando resta
    # menos de 1h de access token.
    def expiring_soon?(within: 3600)
      return true unless expires_at

      Time.now >= (expires_at - within)
    end

    def refresh_expired?(skew: 60)
      return false unless refresh_expires_at

      Time.now >= (refresh_expires_at - skew)
    end

    def to_h
      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in,
        refresh_expires_in: refresh_expires_in,
        token_type: token_type,
        scope: scope,
        obtained_at: obtained_at
      }
    end
  end
end
