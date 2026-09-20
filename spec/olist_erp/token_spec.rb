# frozen_string_literal: true

RSpec.describe OlistErp::Token do
  let(:agora) { Time.utc(2026, 9, 20, 12, 0, 0) }

  def build(**overrides)
    described_class.from_response(
      {
        access_token: "at",
        refresh_token: "rt",
        expires_in: 14_400,
        refresh_expires_in: 86_400,
        token_type: "Bearer"
      }.merge(overrides),
      obtained_at: agora
    )
  end

  it "calcula os vencimentos a partir do momento da emissão" do
    token = build

    expect(token.expires_at).to eq(agora + 14_400)
    expect(token.refresh_expires_at).to eq(agora + 86_400)
  end

  it "considera expirado dentro da folga de segurança" do
    token = build

    allow(Time).to receive(:now).and_return(agora + 14_400 - 30)
    expect(token).to be_expired

    allow(Time).to receive(:now).and_return(agora + 3600)
    expect(token).not_to be_expired
  end

  it "avisa com antecedência para o job de renovação" do
    token = build

    allow(Time).to receive(:now).and_return(agora + 14_400 - 1800)
    expect(token).to be_expiring_soon
    expect(token).not_to be_expired
  end

  it "trata token sem expires_in como já vencido" do
    expect(build(expires_in: nil)).to be_expiring_soon
  end

  it "acusa o refresh token vencido, que obriga novo consentimento" do
    token = build

    allow(Time).to receive(:now).and_return(agora + 86_400)
    expect(token).to be_refresh_expired
  end
end
