require 'rails_helper'

RSpec.describe ::Patreon::Pledges do

  def get_patreon_response(filename)
    FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exists?("#{Rails.root}/tmp/spec")
    FileUtils.cp("#{Rails.root}/plugins/discourse-patreon/spec/fixtures/#{filename}", "#{Rails.root}/tmp/spec/#{filename}")
    File.new("#{Rails.root}/tmp/spec/#{filename}").read
  end

  before do
    campaigns_url = "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges"
    pledges_url = "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=10&sort=created"
    headers = { headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization'=>'Bearer',
                'User-Agent'=>'Faraday v0.11.0'
              }}
    content = { status: 200, headers: { "Content-Type" => "application/json" } }

    campaigns = content.merge({ body: get_patreon_response('campaigns.json') })
    pledges = content.merge({ body: get_patreon_response('pledges.json') })

    stub_request(:get, campaigns_url).to_return(campaigns).with(headers)
    stub_request(:get, pledges_url).to_return(pledges).with(headers)
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
  end

  it "should update campaigns data" do
    freeze_time("2017-11-15T20:59:52+00:00")
    described_class.update_data
    expect(::PluginStore.get(::Patreon::PLUGIN_NAME, 'pledges').count).to eq(2)
  end

end
