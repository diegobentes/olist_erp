# frozen_string_literal: true

module OlistErp
  module Resources
    # Dados da conta conectada. Serve para dar nome à conexão na interface e
    # para confirmar, depois do OAuth, em qual conta o token caiu.
    class Empresa < Base
      def info = client.get("info")
    end
  end
end
