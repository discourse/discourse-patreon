# frozen_string_literal: true

Fabricator(:patreon_tier, from: 'Patreon::Tier') do
  product { Fabricate(:patreon_campaign) }
  external_id { sequence(:external_id) { |i| "id ##{i}" } }
  name { sequence(:name) { |i| "plan #{i}" } }
  amount { sequence(:amount) { |i| i * 5 } }
end
