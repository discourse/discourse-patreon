# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::Patreon::Patron do

  Fabricator(:oauth2_user_info) do
    provider "patreon"
    user
  end

  let(:patrons) { { "111111" => "foo@bar.com", "111112" => "boo@far.com",  "111113" => "roo@aar.com" } }
  let(:pledges) { { "111111" => "100", "111112" => "500" } }
  let(:rewards) { { "0" => { title: "All Patrons", amount_cents: "0" }, "4589" => { title: "Sponsers", amount_cents: "1000" } } }
  let(:reward_users) { { "0" => ["111111", "111112"], "4589" => ["111112"] } }
  let(:titles) { { "111111" => "All Patrons", "111112" => "All Patrons, Sponsers" } }

  before do
    Patreon.set("users", patrons)
    Patreon.set("pledges", pledges)
    Patreon.set("rewards", rewards)
    Patreon.set("reward-users", reward_users)
  end

  it "should find local users matching Patreon user info" do
    Fabricate(:user, email: "foo@bar.com")
    Fabricate(:oauth2_user_info, uid: "111112")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(2)

    local_users.each do |user|
      cf = user.custom_fields
      id = cf["patreon_id"]
      expect(described_class.attr("email", user)).to eq(patrons[id])
      expect(described_class.attr("amount_cents", user)).to eq(pledges[id])
      expect(described_class.attr("rewards", user)).to eq(titles[id])
    end
  end

  it "should find local users matching email address without case-sensitivity" do
    patrons["111111"] = "Foo@bar.com"
    Patreon.set("users", patrons)
    Fabricate(:user, email: "foo@bar.com")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(1)
  end

  it "should sync Discourse groups with Patreon users" do
    user = Fabricate(:user, email: "foo@bar.com")
    ouser = Fabricate(:oauth2_user_info, uid: "111112")
    group1 = Fabricate(:group)
    group2 = Fabricate(:group)
    filters = { group1.id.to_s => ["0"], group2.id.to_s => ["4589"] }
    Patreon.set("filters", filters)
    described_class.sync_groups
    expect(group1.users.to_a - [ouser.user, user]).to eq([])
    expect(group2.users.to_a - [ouser.user]).to eq([])
  end

end
