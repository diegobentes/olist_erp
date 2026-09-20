# frozen_string_literal: true

RSpec.describe OlistErp::Resources::Estoque do
  subject(:estoque) { client.estoque }

  let(:client) { OlistErp::Client.new(access_token: "tok") }
  let(:base) { "https://api.tiny.com.br/public-api/v3" }

  it "lança balanço com depósito" do
    stub_request(:post, "#{base}/estoque/55")
      .with(body: { tipo: "B", quantidade: 12.0, precoUnitario: 30.0, deposito: { id: 7 } }.to_json)
      .to_return(status: 200, body: { idLancamento: 999 }.to_json)

    expect(estoque.balanco(55, quantidade: 12.0, preco_unitario: 30.0, deposito_id: 7))
      .to eq({ idLancamento: 999 })
  end

  it "obtém o saldo do produto" do
    stub_request(:get, "#{base}/estoque/55")
      .to_return(status: 200, body: { id: 55, saldo: 10.0, reservado: 2.0, disponivel: 8.0 }.to_json)

    expect(estoque.obter(55)).to include(disponivel: 8.0)
  end
end
