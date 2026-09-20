# frozen_string_literal: true

require "faraday"
require "json"

module OlistErp
  # Cliente HTTP da API v3. Um client atende UMA conta conectada.
  #
  #   client = OlistErp::Client.new(access_token: conta.access_token)
  #   client.produtos.criar(sku: "ABC", descricao: "Camiseta", tipo: "S")
  #
  # Em vez de um token fixo, dá para passar um bloco que devolve o token válido
  # no momento da chamada. É assim que a aplicação encaixa a renovação
  # automática sem a gem precisar saber onde os tokens moram:
  #
  #   OlistErp::Client.new { conta.access_token_valido! }
  class Client
    BASE_URL = "https://api.tiny.com.br/public-api/v3"
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_TIMEOUT = 30
    DEFAULT_OPEN_TIMEOUT = 10

    attr_reader :base_url, :max_retries, :last_rate_limit

    def initialize(access_token: nil, base_url: BASE_URL, max_retries: DEFAULT_MAX_RETRIES,
                   timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT,
                   adapter: nil, logger: nil, user_agent: nil, sleeper: nil, &token_provider)
      raise ConfigurationError, "informe access_token: ou um bloco que devolva o token" if access_token.nil? && token_provider.nil?

      @static_token = access_token
      @token_provider = token_provider
      @base_url = base_url
      @max_retries = max_retries
      @timeout = timeout
      @open_timeout = open_timeout
      @adapter = adapter
      @logger = logger
      @user_agent = user_agent || "olist_erp-rb/#{OlistErp::VERSION}"
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @last_rate_limit = RateLimit.new
    end

    def access_token
      @token_provider ? @token_provider.call : @static_token
    end

    def produtos = @produtos ||= Resources::Produtos.new(self)
    def estoque = @estoque ||= Resources::Estoque.new(self)
    def categorias = @categorias ||= Resources::Categorias.new(self)
    def marcas = @marcas ||= Resources::Marcas.new(self)
    def depositos = @depositos ||= Resources::Depositos.new(self)
    def listas_de_precos = @listas_de_precos ||= Resources::ListasDePrecos.new(self)
    def empresa = @empresa ||= Resources::Empresa.new(self)

    def get(path, params = {}) = request(:get, path, params: params)
    def post(path, body = nil, params = {}) = request(:post, path, body: body, params: params)
    def put(path, body = nil, params = {}) = request(:put, path, body: body, params: params)
    def delete(path, params = {}) = request(:delete, path, params: params)

    # Devolve o corpo já parseado. Levanta a subclasse de ApiError que couber.
    def request(method, path, params: {}, body: nil, attempt: 1)
      response = perform(method, path, params, body)
      @last_rate_limit = RateLimit.from_headers(response.headers)

      return parse(response.body) if response.success?

      retry_delay = retry_delay_for(response, attempt)
      if retry_delay
        @sleeper.call(retry_delay)
        return request(method, path, params: params, body: body, attempt: attempt + 1)
      end

      raise error_for(response)
    end

    private

    def perform(method, path, params, body)
      connection.public_send(method, path) do |req|
        req.headers.update(build_headers)
        req.params.update(compact(params)) if params && !params.empty?
        req.body = JSON.generate(body) unless body.nil?
      end
    end

    # Só o 429 e as indisponibilidades (5xx) são transitórios. Repetir um 400 ou
    # um 401 devolve exatamente o mesmo erro e só queima o limite da conta.
    def retry_delay_for(response, attempt)
      return nil if attempt >= max_retries
      return nil unless response.status == 429 || response.status >= 500

      if response.status == 429
        reset = RateLimit.from_headers(response.headers).reset_in
        return (reset && reset.positive? ? reset : 60) + 1
      end

      2**attempt
    end

    ERROS_POR_STATUS = {
      400 => [ValidationError, nil],
      401 => [AuthenticationError, "Token inválido ou expirado"],
      403 => [ForbiddenError, "O aplicativo não tem permissão para este recurso"],
      404 => [NotFoundError, "Recurso não encontrado na conta"]
    }.freeze
    private_constant :ERROS_POR_STATUS

    def error_for(response)
      status = response.status
      args = {
        status: status,
        body: parse(response.body),
        request_id: response.headers && response.headers["x-request-id"]
      }

      if status == 429
        reset = RateLimit.from_headers(response.headers).reset_in
        return RateLimitError.new("Limite de requisições da conta atingido", retry_after: reset, **args)
      end

      classe, mensagem = ERROS_POR_STATUS[status]
      return classe.new(mensagem, **args) if classe
      return ServerError.new("ERP indisponível (HTTP #{status})", **args) if status >= 500

      ApiError.new("Resposta inesperada do ERP (HTTP #{status})", **args)
    end

    def parse(body)
      return nil if body.nil? || body.to_s.strip.empty?

      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      { mensagem: body.to_s }
    end

    def compact(params)
      params.reject { |_k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    end

    def connection
      @connection ||= Faraday.new(url: "#{base_url}/") do |f|
        f.options.timeout = @timeout
        f.options.open_timeout = @open_timeout
        f.response :logger, @logger if @logger
        f.adapter(*Array(@adapter || Faraday.default_adapter))
      end
    end

    # O token é resolvido a cada chamada (pode ter sido renovado no meio do
    # caminho), então ele entra por aqui e não no build da conexão.
    def build_headers
      {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => @user_agent
      }
    end
  end
end
