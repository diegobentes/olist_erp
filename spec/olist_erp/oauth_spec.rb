# frozen_string_literal: true

RSpec.describe OlistErp::OAuth do
  subject(:oauth) do
    described_class.new(
      client_id: "cid",
      client_secret: "sec",
      redirect_uri: "https://app.test/callback"
    )
  end

  let(:token_url) { "https://accounts.tiny.com.br/realms/tiny/protocol/openid-connect/token" }

  describe "#authorize_url" do
    it "monta a URL de consentimento com o state informado" do
      url = oauth.authorize_url(state: "conta-7")

      expect(url).to start_with("https://accounts.tiny.com.br/realms/tiny/protocol/openid-connect/auth?")
      expect(url).to include("client_id=cid")
      expect(url).to include("redirect_uri=https%3A%2F%2Fapp.test%2Fcallback")
      expect(url).to include("response_type=code")
      expect(url).to include("state=conta-7")
    end

    it "exige redirect_uri" do
      sem_redirect = described_class.new(client_id: "cid", client_secret: "sec")

      expect { sem_redirect.authorize_url }.to raise_error(OlistErp::ConfigurationError, /redirect_uri/)
    end
  end

  describe "#exchange_code" do
    it "troca o código pelo par de tokens" do
      stub_request(:post, token_url)
        .with(body: hash_including(grant_type: "authorization_code", code: "abc123", client_secret: "sec"))
        .to_return(
          status: 200,
          body: { access_token: "at", refresh_token: "rt", expires_in: 14_400, refresh_expires_in: 86_400 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      token = oauth.exchange_code("abc123")

      expect(token.access_token).to eq("at")
      expect(token.refresh_token).to eq("rt")
      expect(token.expires_in).to eq(14_400)
    end

    it "levanta AuthenticationError com a descrição devolvida pelo ERP" do
      stub_request(:post, token_url).to_return(
        status: 400,
        body: { error: "invalid_grant", error_description: "Code not valid" }.to_json
      )

      expect { oauth.exchange_code("expirado") }
        .to raise_error(OlistErp::AuthenticationError, /Code not valid/)
    end
  end

  describe "#refresh" do
    it "usa o grant de refresh_token" do
      stub_request(:post, token_url)
        .with(body: hash_including(grant_type: "refresh_token", refresh_token: "rt-antigo"))
        .to_return(status: 200, body: { access_token: "novo", refresh_token: "rt-novo", expires_in: 14_400 }.to_json)

      token = oauth.refresh("rt-antigo")

      expect(token.access_token).to eq("novo")
      expect(token.refresh_token).to eq("rt-novo")
    end
  end
end
