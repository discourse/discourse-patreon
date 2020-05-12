# frozen_string_literal: true

require 'rails_helper'

require_relative '../fabricators/product_fabricator'
require_relative '../fabricators/plan_fabricator'

describe Patreon::PatreonAdminController do

  describe '#list' do
    let(:group1) { Fabricate(:group) }
    let(:group2) { Fabricate(:group) }
    let(:admin) { Fabricate(:admin) }
    let(:filters) { { group1.id.to_s => ["0"], group2.id.to_s => ["208"], "777" => ["888"] } }
    let(:tier1) { Fabricate(:patreon_tier) }
    let(:tier2) { Fabricate(:patreon_tier) }

    before do
      sign_in(admin)
      SiteSetting.patreon_enabled = true
      SiteSetting.patreon_creator_access_token = "TOKEN"
      SiteSetting.patreon_creator_refresh_token = "TOKEN"
      Patreon.set("filters", filters)
      tier1
      tier2
    end

    it 'should display list of patreon groups' do
      get '/patreon/list.json'

      result = JSON.parse(response.body)
      expect(result["filters"].count).to eq(2)
      expect(result["plans"].count).to eq(2)
    end

    it 'should display list of rewards' do
      get '/patreon/plans.json'

      tiers = JSON.parse(response.body)["patreon_admin"]
      expect(tiers.count).to eq(2)
    end

    it 'should update existing filter' do
      ids = [tier1.id, tier2.id]

      post '/patreon/list.json', params: {
        plan_ids: ids,
        group_id: group1.id
      }

      expect(Patreon.get("filters")[group1.id.to_s]).to eq(ids)
    end

    it 'should delete an filter' do
      expect {
        delete '/patreon/list.json', params: {
          group_id: group1.id
        }
      }.to change { Patreon.get("filters").count }.by(-1)
      expect(Patreon.get("filters")[group1.id.to_s]).to eq(nil)
    end

    it 'should sync patreon groups' do
      Patreon::Member.expects(:sync_groups)
      post '/patreon/sync_groups.json'
    end

    it 'should enqueue job to sync patrons and groups' do
      Jobs.expects(:enqueue).with(:patreon_sync_patrons_to_groups)
      post '/patreon/update_data.json'
    end
  end
end
