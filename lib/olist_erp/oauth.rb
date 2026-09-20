# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"
require "uri"

module OlistErp
  # Fluxo OAuth 2 (authorization code) contra o Keycloak do ERP.
  #
  # O client_id/client_secret são do *aplicativo*, criados uma vez no painel do
  # ERP. Já os tokens são por *conta conectada* — é o que permite o mesmo
  # aplicativo operar várias contas do Tiny/Olist ao mesmo tempo.
  class OAuth
    ACCOUNTS_URL = "https://accounts.tiny.com.br"
    REALM_PATH = "/realms/tiny/protocol/openid-connect"
    DEFAULT_SCOPE = "openid"

    attr_reader :client_id, :client_secret, :redirect_uri, :accounts_url

    def initialize(client_id:, client_secret:, redirect_uri: nil, accounts_url: ACCOUNTS_URL, adapter: nil, logger: nil)
      raise ConfigurationError, "client_id é obrigatório" if to_s_or_nil(client_id).nil?
      raise ConfigurationError, "client_secret é obrigatório" if to_s_or_nil(client_secret).nil?

      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @accounts_url = accounts_url
      @adapter = adapter
      @logger = logger
    end

    # URL para onde redirecionar quem está conectando a conta.
    # O +state+ é devolvido intacto no callback: use-o para saber qual conta
    # está sendo conectada e para barrar CSRF.
    def authorize_url(state: SecureRandom.hex(16), scope: DEFAULT_SCOPE, redirect_uri: self.redirect_uri)
      raise ConfigurationError, "redirect_uri é obrigatório" if to_s_or_nil(redirect_uri).nil?

      query = URI.encode_www_form(
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope,
        response_type: "code",
        state: state
      )

      "#{accounts_url}#{REALM_PATH}/auth?#{query}"
    end

    # Troca o código do callback pelo par access/refresh token.
    def exchange_code(code, redirect_uri: self.redirect_uri)
      raise ConfigurationError, "redirect_uri é obrigatório" if to_s_or_nil(redirect_uri).nil?

      token_request(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri
      )
    end

    # Renova o access token. O Keycloak devolve um refresh token novo junto,
    # então guarde os dois — é a rotação que mantém a conta conectada além das
    # 24h de validade do refresh.
    def refresh(refresh_token)
      raise ConfigurationError, "refresh_token é obrigatório" if to_s_or_nil(refresh_token).nil?

      token_request(grant_type: "refresh_token", refresh_token: refresh_token)
    end

    # Invalida o refresh token no ERP (desconectar a conta).
    # Levanta AuthenticationError se o ERP recusar a revogação.
    def revoke(refresh_token)
      response = connection.post("#{REALM_PATH}/logout") do |req|
        req.body = {
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: refresh_token
        }
      end

      raise_oauth_error(response, parse(response.body)) unless response.success?

      nil
    end

    private

    attr_reader :logger

    def token_request(**params)
      requested_at = Time.now
      response = connection.post("#{REALM_PATH}/token") do |req|
        req.body = params.merge(client_id: client_id, client_secret: client_secret)
      end

      payload = parse(response.body)
      raise_oauth_error(response, payload) unless response.success?

      Token.from_response(payload, obtained_at: requested_at)
    end

    def raise_oauth_error(response, payload)
      descricao = payload[:error_description] || payload[:error] || response.body.to_s
      message = "Falha na autenticação OAuth (#{response.status}): #{descricao}"

      raise AuthenticationError.new(message, status: response.status, body: payload)
    end

    def parse(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      { error_description: body.to_s }
    end

    def connection
      @connection ||= Faraday.new(url: accounts_url) do |f|
        f.request :url_encoded
        f.response :logger, logger if logger
        f.adapter(*Array(@adapter || Faraday.default_adapter))
      end
    end

    def to_s_or_nil(value)
      s = value.to_s.strip
      s.empty? ? nil : s
    end
  end
end
