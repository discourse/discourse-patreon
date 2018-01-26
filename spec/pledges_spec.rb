require 'rails_helper'
require_relative 'spec_helper'

RSpec.describe ::Patreon::Campaign do
  include_context "spec helper"

  Fabricator(:oauth2_user_info) do
    provider "patreon"
    user
  end

  before do
    campaigns_url = "https://api.patreon.com/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page%5Bcount%5D=100"
    pledges_url = "https://www.patreon.com/api/oauth2/api/campaigns/70261/pledges?page%5Bcount%5D=100&sort=created"
    headers = { headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization' => 'Bearer',
                'User-Agent' => 'Faraday v0.11.0'
              } }
    content = { status: 200, headers: { "Content-Type" => "application/json" } }

    campaigns = content.merge(body: get_patreon_response('campaigns.json'))
    pledges = content.merge(body: get_patreon_response('pledges.json'))

    stub_request(:get, campaigns_url).to_return(campaigns).with(headers)
    stub_request(:get, pledges_url).to_return(pledges).with(headers)
    SiteSetting.patreon_enabled = true
    SiteSetting.patreon_declined_pledges_grace_period_days = 7
  end

  it "should update campaigns and group users data" do
    freeze_time("2017-11-15T20:59:52+00:00")
    expect {
      described_class.update!
    }.to change { Group.count }.by(1)
      .and change { Badge.count }.by(1)

    expect(get('pledges').count).to eq(2)
    expect(get('rewards').count).to eq(5)
    expect(get('users').count).to eq(3)
    expect(get('reward-users')["0"].count).to eq(2)
    expect(get('filters').count).to eq(1)

    freeze_time("2017-11-11T20:59:52+00:00")
    expect {
      described_class.update!
    }.to change { get('pledges').count }.by(1)
      .and change { get('reward-users')["0"].count }.by(1)

    expect { # To check `add_model_callback(User, :after_commit, on: :create)` in plugin.rb
      get('users').each do |id, u|
        cf = Fabricate(:user, email: u[:email]).custom_fields
        expect(cf["patreon_id"]).to eq(id)
        expect(cf["patreon_email"]).to eq(u[:email])
        expect(cf["patreon_amount_cents"]).to eq(get("pledges")[id])
      end
    }.to change { GroupUser.count }.by(3)
  end

  it "should find user by patreon id or email" do
    users = { "111111" => { "email" => "foo@bar.com" },
              "111112" => { "email" => "boo@far.com" },
              "111113" => { "email" => "roo@aar.com" }
            }
    ::Patreon.set("users", users)

    pledges = { "111111" => "100", "111112" => "500" }
    ::Patreon.set("pledges", pledges)

    rewards = { "0" => { title: "All Patrons", amount_cents: "0" }, "4589" => { title: "Sponsers", amount_cents: "1000" } }
    ::Patreon.set("rewards", rewards)

    reward_users = { "0" => ["111111", "111112"], "4589" => ["111112"] }
    titles = { "111111" => "All Patrons", "111112" => "All Patrons, Sponsers" }
    ::Patreon.set("reward-users", reward_users)

    Fabricate(:user, email: "foo@bar.com")
    Fabricate(:oauth2_user_info, uid: "111112")

    local_users = Patreon::Patron.get_local_users
    expect(local_users.count).to eq(2)

    local_users.each do |user|
      cf = user.custom_fields
      id = cf["patreon_id"]
      expect(cf["patreon_email"]).to eq(users[id]["email"])
      expect(cf["patreon_amount_cents"]).to eq(pledges[id])
      expect(cf["patreon_rewards"]).to eq(titles[id])
    end
  end

end
