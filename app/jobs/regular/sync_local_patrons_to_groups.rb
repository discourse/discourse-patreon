# frozen_string_literal: true

module ::Jobs
  class SyncLocalPatronsToGroups < ::Jobs::Base

    def execute(args)
      ::Patreon::Patron.sync_groups
    end
  end
end
