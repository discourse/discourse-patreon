# frozen_string_literal: true

require 'json'

module ::Patreon
  class Campaign < ::Product

    def sync!
      params = {}
      params["include"] = "currently_entitled_tiers,user"
      params["fields"] = {}
      params["fields"]["tier"] = Tier::API_FIELDS.join(",")
      params["fields"]["member"] = Member::API_FIELDS.join(",")

      update(params)
      ::Patreon::Member.sync_groups

      # Sets all patrons to the seed group by default on first run
      filters = Patreon.get('filters')
      Patreon::Seed.seed_content! if filters.blank?

      ::MessageBus.publish '/patreon/background_sync', true
    end

    private

    def update(params, cursor = nil)
      if cursor.present?
        params["page"] ||= {}
        params["page"]["cursor"] = cursor
        cursor = nil
      end

      response = Api.get("campaigns/#{external_id}/members", params)
      Patreon.update(response, id)
      cursor = response&.dig("meta", "pagination", "cursors", "next")

      update(params, cursor) if cursor.present?
    end
  end
end
