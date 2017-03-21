module ::Patreon
  class SyncPatronsToGroups < ::Jobs::Scheduled
    every 3.hours

    def execute(args)
      Pledges.update_patrons! if SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_sync_patrons_to_group
    end
  end
end