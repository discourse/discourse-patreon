require 'rails_helper'

RSpec.describe ::Patreon::Patron do

  Fabricator(:oauth2_user_info) do
    provider "patreon"
    user
  end

  let(:patrons) { { "111111" => { "email" => "foo@bar.com" }, "111112" => { "email" => "boo@far.com" },  "111113" => { "email" => "roo@aar.com" } } }
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
      expect(cf["patreon_email"]).to eq(patrons[id]["email"])
      expect(cf["patreon_amount_cents"]).to eq(pledges[id])
      expect(cf["patreon_rewards"]).to eq(titles[id])
    end
  end

  it "should sync Discourse groups with Patreon users" do
    user = Fabricate(:user, email: "foo@bar.com")
    ouser = Fabricate(:oauth2_user_info, uid: "111112")
    group1 = Fabricate(:group)
    group2 = Fabricate(:group)
    filters = { group1.id.to_s => ["0"], group2.id.to_s => ["4589"] }
    Patreon.set("filters", filters)
    described_class.sync_groups
    expect(group1.users.to_a).to eq([user, ouser.user])
    expect(group2.users.to_a).to eq([ouser.user])
  end

end
