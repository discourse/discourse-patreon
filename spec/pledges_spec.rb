require 'rails_helper'

RSpec.describe ::Patreon::Pledges do

  Fabricator(:oauth2_user_info) do
    provider "patreon"
    user
  end

  def get(key)
    ::Patreon.get(key)
  end

  def get_patreon_response(filename)
    FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exists?("#{Rails.root}/tmp/spec")
    FileUtils.cp("#{Rails.root}/plugins/discourse-patreon/spec/fixtures/#{filename}", "#{Rails.root}/tmp/spec/#{filename}")
    File.new("#{Rails.root}/tmp/spec/#{filename}").read
  end

  before do
    campaigns_url = "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=200"
    pledges_url = "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=200&sort=created"
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
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
  end

  it "should update campaigns and group users data" do
    freeze_time("2017-11-15T20:59:52+00:00")
    expect {
      described_class.update_data
    }.to change { Group.count }.by(1)
    .and change { Badge.count }.by(1)

    expect(get('pledges').count).to eq(2)
    expect(get('rewards').count).to eq(2)
    expect(get('users').count).to eq(3)
    expect(get('reward-users').count).to eq(3)
    expect(get('filters').count).to eq(1)

    freeze_time("2017-11-11T20:59:52+00:00")
    expect {
      described_class.update_data
    }.to change { get('pledges').count }.by(1)
    .and change { get('reward-users').count }.by(1)

    expect { # To check `add_model_callback(User, :after_commit, on: :create)` in plugin.rb
      get('users').each do |id, user|
        Fabricate(:user, email: user[:email])
      end
    }.to change { GroupUser.count }.by(3)
  end

  it "should find user by patreon id or email" do
    users = {"111111"=>{"email"=>"foo@bar.com"}, "111112"=>{"email"=>"boo@far.com"}, "111113"=>{"email"=>"roo@aar.com"}}
    ::Patreon.set("users", users)

    Fabricate(:user, email: "foo@bar.com")
    Fabricate(:oauth2_user_info, uid: "111112")

    expect(described_class.patreon_users_to_discourse_users(users.keys).count).to eq(2)
  end

end
