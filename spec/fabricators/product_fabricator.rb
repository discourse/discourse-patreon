# frozen_string_literal: true

Fabricator(:patreon_campaign, from: 'Patreon::Campaign') do
  external_id { sequence(:external_id) { |i| "id ##{i}" } }
end
