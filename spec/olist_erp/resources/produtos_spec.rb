# frozen_string_literal: true

RSpec.describe OlistErp::Resources::Produtos do
  subject(:produtos) { client.produtos }

  let(:client) { OlistErp::Client.new(access_token: "tok") }
  let(:base) { "https://api.tiny.com.br/public-api/v3" }

  describe "#criar" do
    it "manda o payload como JSON e devolve o produto criado" do
      payload = { sku: "CAM-001", descricao: "Camiseta", tipo: "S" }

      stub_request(:post, "#{base}/produtos")
        .with(body: payload.to_json)
        .to_return(status: 200, body: { id: 55, codigo: "CAM-001", descricao: "Camiseta" }.to_json)

      expect(produtos.criar(payload)).to include(id: 55)
    end
  end

  describe "#atualizar_preco" do
    it "envia só os preços informados" do
      stub = stub_request(:put, "#{base}/produtos/55/preco")
             .with(body: { preco: 99.9, precoCusto: 40.0 }.to_json)
             .to_return(status: 200, body: "{}")

      produtos.atualizar_preco(55, preco: 99.9, preco_custo: 40.0)

      expect(stub).to have_been_requested
    end
  end

  describe "#listar" do
    it "devolve uma página com a paginação do ERP" do
      stub_request(:get, "#{base}/produtos")
        .with(query: { limit: 100, offset: 0, gtin: "789" })
        .to_return(status: 200, body: {
          itens: [{ id: 1 }, { id: 2 }],
          paginacao: { limit: 100, offset: 0, total: 2 }
        }.to_json)

      pagina = produtos.listar(gtin: "789")

      expect(pagina.size).to eq(2)
      expect(pagina).to be_last_page
    end
  end

  describe "#todos" do
    it "percorre todas as páginas" do
      stub_request(:get, "#{base}/produtos").with(query: { limit: 2, offset: 0 })
                                            .to_return(status: 200, body: {
                                              itens: [{ id: 1 }, { id: 2 }],
                                              paginacao: { limit: 2, offset: 0, total: 3 }
                                            }.to_json)
      stub_request(:get, "#{base}/produtos").with(query: { limit: 2, offset: 2 })
                                            .to_return(status: 200, body: {
                                              itens: [{ id: 3 }],
                                              paginacao: { limit: 2, offset: 2, total: 3 }
                                            }.to_json)

      expect(produtos.todos(limit: 2).map { |p| p[:id] }).to eq([1, 2, 3])
    end

    it "para quando a página volta vazia, mesmo sem total confiável" do
      stub_request(:get, "#{base}/produtos").with(query: { limit: 2, offset: 0 })
                                            .to_return(status: 200, body: {
                                              itens: [{ id: 1 }, { id: 2 }],
                                              paginacao: { limit: 2, offset: 0 }
                                            }.to_json)
      stub_request(:get, "#{base}/produtos").with(query: { limit: 2, offset: 2 })
                                            .to_return(status: 200, body: {
                                              itens: [],
                                              paginacao: { limit: 2, offset: 2 }
                                            }.to_json)

      expect(produtos.todos(limit: 2).map { |p| p[:id] }).to eq([1, 2])
    end
  end

  describe "#obter_por_sku" do
    it "confere a igualdade do código, já que o filtro da API é por conteúdo" do
      stub_request(:get, "#{base}/produtos")
        .with(query: { limit: 50, offset: 0, codigoProduto: "CAM-1" })
        .to_return(status: 200, body: {
          itens: [{ id: 1, sku: "CAM-10" }, { id: 2, sku: "CAM-1" }],
          paginacao: { limit: 50, offset: 0, total: 2 }
        }.to_json)

      expect(produtos.obter_por_sku("CAM-1")).to include(id: 2)
    end
  end
end
