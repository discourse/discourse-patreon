require 'rails_helper'

RSpec.describe ::Patreon do

  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }
  let(:filters) { { group.id.to_s => [] } }

  before {
    described_class.set("filters", filters)
    group.add(user1)
  }

  context("donation prompt enabled") {
    before {
      SiteSetting.patreon_donation_prompt_enabled = true
    }

    it("should not show donation prompt to patrons") {
      expect(described_class.show_donation_prompt_to_user?(user1)).to eq(false)
    }

    it("should show donation prompt to non-patrons") {
      expect(described_class.show_donation_prompt_to_user?(user2)).to eq(true)
    }
  }

  context("donation prompt disabled") {
    before {
      SiteSetting.patreon_donation_prompt_enabled = false
    }

    it("should show donation prompt to non-patrons") {
      expect(described_class.show_donation_prompt_to_user?(user2)).to eq(false)
    }
  }

end
