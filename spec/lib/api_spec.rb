# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::Patreon::Api do

  let(:url) { "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100" }

  def stub(status)
    content = {
      status: status,
      headers: {
        "Content-Type" => "application/json"
      },
      body: '{}'
    }

    stub_request(:get, url).to_return(content)
  end

  it "should add admin warning message for invalid api response" do
    stub(401)

    expect(described_class.get(url)).to eq(error: I18n.t(described_class::INVALID_RESPONSE))
    expect(AdminDashboardData.problem_message_check(described_class::ACCESS_TOKEN_INVALID).sub('%{base_path}', '')).to eq(I18n.t(described_class::ACCESS_TOKEN_INVALID, base_path: ""))

    stub(200)

    expect(described_class.get(url)).to eq({})
    expect(AdminDashboardData.problem_message_check(described_class::ACCESS_TOKEN_INVALID)).to eq(nil)
  end

  it "should add warning log" do
    stub(500)

    Discourse.expects(:warn_exception).once
    expect(described_class.get(url)).to eq(error: I18n.t(described_class::INVALID_RESPONSE))
  end

end
