# frozen_string_literal: true

RSpec.describe OlistErp::Client do
  subject(:client) { described_class.new(access_token: "tok", sleeper: sleeper) }

  let(:sleeper) { ->(seconds) { dormidas << seconds } }
  let(:dormidas) { [] }
  let(:base) { "https://api.tiny.com.br/public-api/v3" }

  it "envia o bearer token e os cabeçalhos JSON" do
    stub = stub_request(:get, "#{base}/info")
           .with(headers: { "Authorization" => "Bearer tok", "Accept" => "application/json" })
           .to_return(status: 200, body: { cnpj: "00.000.000/0001-00" }.to_json)

    expect(client.empresa.info).to eq({ cnpj: "00.000.000/0001-00" })
    expect(stub).to have_been_requested
  end

  it "resolve o token a cada chamada quando recebe um bloco" do
    tokens = %w[primeiro segundo]
    rotativo = described_class.new { tokens.shift }

    stub_request(:get, "#{base}/info").to_return(status: 200, body: "{}")

    rotativo.empresa.info
    rotativo.empresa.info

    expect(a_request(:get, "#{base}/info").with(headers: { "Authorization" => "Bearer primeiro" })).to have_been_made
    expect(a_request(:get, "#{base}/info").with(headers: { "Authorization" => "Bearer segundo" })).to have_been_made
  end

  it "exige token ou bloco" do
    expect { described_class.new }.to raise_error(OlistErp::ConfigurationError, /access_token/)
  end

  it "guarda os headers de limite da última resposta" do
    stub_request(:get, "#{base}/info").to_return(
      status: 200,
      body: "{}",
      headers: { "X-RateLimit-Limit" => "120", "X-RateLimit-Remaining" => "3", "X-RateLimit-Reset" => "12" }
    )

    client.empresa.info

    expect(client.last_rate_limit.to_h).to eq(limit: 120, remaining: 3, reset_in: 12)
  end

  describe "erros" do
    it "traduz 400 em ValidationError com os campos" do
      stub_request(:post, "#{base}/produtos").to_return(
        status: 400,
        body: {
          mensagem: "Ocorreram erros de validação",
          detalhes: [{ campo: "sku", mensagem: "O campo sku é obrigatório" }]
        }.to_json
      )

      expect { client.produtos.criar(descricao: "x") }.to raise_error(OlistErp::ValidationError) do |erro|
        expect(erro.status).to eq(400)
        expect(erro.mensagens_de_campo).to eq(["sku: O campo sku é obrigatório"])
        expect(erro.message).to include("Ocorreram erros de validação")
      end
    end

    it "traduz 401 em AuthenticationError" do
      stub_request(:get, "#{base}/produtos/1").to_return(status: 401, body: "")

      expect { client.produtos.obter(1) }.to raise_error(OlistErp::AuthenticationError)
    end

    it "traduz 404 em NotFoundError" do
      stub_request(:get, "#{base}/produtos/1").to_return(status: 404, body: "")

      expect { client.produtos.obter(1) }.to raise_error(OlistErp::NotFoundError)
    end

    it "não repete um 400, que devolveria sempre o mesmo erro" do
      stub_request(:post, "#{base}/produtos").to_return(status: 400, body: "{}")

      expect { client.produtos.criar({}) }.to raise_error(OlistErp::ValidationError)
      expect(a_request(:post, "#{base}/produtos")).to have_been_made.once
      expect(dormidas).to be_empty
    end
  end

  describe "limite de requisições" do
    it "espera o reset e repete em 429" do
      stub_request(:get, "#{base}/produtos/9")
        .to_return(status: 429, body: "{}", headers: { "X-RateLimit-Reset" => "5" })
        .then.to_return(status: 200, body: { id: 9 }.to_json)

      expect(client.produtos.obter(9)).to eq({ id: 9 })
      expect(dormidas).to eq([6])
    end

    it "desiste depois do máximo de tentativas e levanta RateLimitError" do
      stub_request(:get, "#{base}/produtos/9")
        .to_return(status: 429, body: "{}", headers: { "X-RateLimit-Reset" => "2" })

      expect { client.produtos.obter(9) }.to raise_error(OlistErp::RateLimitError) do |erro|
        expect(erro.retry_after).to eq(2)
      end
      expect(a_request(:get, "#{base}/produtos/9")).to have_been_made.times(3)
    end

    it "repete 5xx com espera crescente" do
      stub_request(:get, "#{base}/info")
        .to_return(status: 503, body: "")
        .then.to_return(status: 200, body: "{}")

      client.empresa.info

      expect(dormidas).to eq([2])
    end
  end
end
