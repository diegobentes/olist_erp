# frozen_string_literal: true

module OlistErp
  # Raiz de tudo que a gem levanta, para quem quiser um rescue só.
  class Error < StandardError; end

  # Faltou configuração (client_id, client_secret, access_token...).
  class ConfigurationError < Error; end

  # Erro devolvido pela API, já com o corpo desempacotado.
  class ApiError < Error
    attr_reader :status, :body, :detalhes, :request_id

    def initialize(message = nil, status: nil, body: nil, request_id: nil)
      @status = status
      @body = body
      @request_id = request_id
      @detalhes = Array(body.is_a?(Hash) ? body[:detalhes] : nil)
      super(message || default_message)
    end

    # Ex.: ["codigo: O campo código é obrigatório"]
    def mensagens_de_campo
      detalhes.map { |d| [d[:campo], d[:mensagem]].compact.join(": ") }
    end

    private

    def default_message
      geral = body[:mensagem] if body.is_a?(Hash)
      [geral, mensagens_de_campo.join("; ")].reject { |p| p.nil? || p.empty? }.join(" — ")
    end
  end

  # 400 — o payload não passou na validação do ERP.
  class ValidationError < ApiError; end
  # 401 — token ausente, expirado ou inválido.
  class AuthenticationError < ApiError; end
  # 403 — o aplicativo não tem o escopo/permissão para esse recurso.
  class ForbiddenError < ApiError; end
  # 404 — recurso inexistente na conta.
  class NotFoundError < ApiError; end

  # 429 — estourou o limite por minuto. O limite é por CONTA, não por aplicativo.
  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil, **)
      @retry_after = retry_after
      super(message, **)
    end
  end

  # 5xx — indisponibilidade do lado do ERP.
  class ServerError < ApiError; end
end
