module ::Jobs
  class PatreonSyncPatronsToGroups < ::Jobs::Scheduled
    every 6.hours

    def execute(args)
      Patreon::Pledges.update_patrons! if SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token
    end
  end
end
