# frozen_string_literal: true

module ::Patreon
  class Tier < ::Plan
    API_FIELDS = %W{
      title
      amount_cents
    }

    def self.update(data, campaign_id = nil)
      campaign_id ||= Patreon.campaign.id
      ids = Tier.pluck(:external_id)
      data.each do |object|
        next unless object["type"] == "tier" || ids.include?(object["id"])
        attrs = object["attributes"]
        tier = Tier.where(product_id: campaign_id, external_id: object["id"]).first_or_initialize
        tier.tap do |t|
          t.name = attrs["title"]
          t.amount = attrs["amount_cents"].to_i / 100
          t.save! if t.changed?
        end
      end
    end
  end
end
