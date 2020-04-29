# frozen_string_literal: true

module ::Jobs
  class SyncPatronGroups < ::Jobs::Base

    def execute(args)
      member = ::Patreon::Member.find_by(external_id: args[:patreon_id])
      return member.blank?

      member.sync_groups
    end
  end
end
