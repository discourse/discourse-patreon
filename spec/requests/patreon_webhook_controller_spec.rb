# frozen_string_literal: true

require "rails_helper"
require "openssl"
require "json"
require_relative "../spec_helper"

RSpec.describe ::Patreon::PatreonWebhookController do
  before { Jobs.run_immediately! }

  describe "index" do
    describe "header checking" do
      it "raises InvalidAccess error without header params" do
        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) { post "/patreon/webhook" }

        expect(response.status).to eq(403)
      end

      it "raises InvalidAccess error with invalid header params" do
        expect_not_enqueued_with(job: :patreon_sync_patrons_to_groups) do
          post "/patreon/webhook", headers: { "X-Patreon-Event": "", "X-Patreon-Signature": "" }
        end

        expect(response.status).to eq(403)
      end
    end

    describe "enqueue job" do
      let(:body) { get_patreon_response("pledge.json") }
      let(:digest) { OpenSSL::Digest::MD5.new }
      let(:secret) { SiteSetting.patreon_webhook_secret = "WEBHOOK SECRET" }

      before do
        Patreon.set(
          "rewards",
          "0": {
            title: "All Patrons",
            amount_cents: 0,
          },
          "999999": {
            title: "Premium",
            amount_cents: 1000,
          },
        )
      end

      def add_pledge
        pledge_data = JSON.parse(body)
        Patreon::Pledge.create!(pledge_data.dup)

        pledge_data
      end

      def post_request(body, event, type = "pledges")
        post "/patreon/webhook",
             params: body,
             headers: {
               "X-Patreon-Event": "#{type}:#{event}",
               "X-Patreon-Signature": OpenSSL::HMAC.hexdigest(digest, secret, body),
             }
      end

      it "for event pledge:create" do
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        Patreon.set("filters", group.id.to_s => ["0"])

        expect { post_request(body, "create") }.to change { Patreon::Pledge.all.keys.count }.by(
          1,
        ).and change { Patreon::Patron.all.keys.count }.by(1).and change {
                      Patreon::RewardUser.all.keys.count
                    }.by(2)

        expect(group.users).to include(user)
      end

      it "for event members:pledge:create" do
        body = get_patreon_response("member.json")
        user = Fabricate(:user, email: "roo@aar.com")
        group = Fabricate(:group)
        Patreon.set("filters", group.id.to_s => ["0"])

        expect { post_request(body, "create", "members:pledge") }.to change {
          Patreon::Pledge.all.keys.count
        }.by(1).and change { Patreon::Patron.all.keys.count }.by(1).and change {
                      Patreon::RewardUser.all.keys.count
                    }.by(2)

        expect(group.users).to include(user)
      end

      it "for event pledge:update" do
        pledge_data = add_pledge
        pledge = pledge_data["data"]
        pledge["attributes"]["amount_cents"] = 987
        patron_id = pledge["relationships"]["patron"]["data"]["id"]
        pledge_data = JSON.pretty_generate(pledge_data)

        expect(Patreon.get("pledges")[patron_id]).to eq(250)
        post_request(pledge_data, "update")
        expect(Patreon.get("pledges")[patron_id]).to eq(987)
      end

      it "for event pledge:delete" do
        pledge_data = add_pledge
        patron_id = pledge_data["data"]["relationships"]["patron"]["data"]["id"]
        reward_id = pledge_data["data"]["relationships"]["reward"]["data"]["id"]

        expect { post_request(body, "delete") }.to change { Patreon::Pledge.all.keys.count }.by(
          -1,
        ).and change { Patreon::Patron.all.keys.count }.by(-1).and change {
                      Patreon::RewardUser.all[reward_id].count
                    }.by(-1)
      end
    end
  end
end
