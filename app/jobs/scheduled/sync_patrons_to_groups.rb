module ::Patreon
  class SyncPatronsToGroups < ::Jobs::Scheduled
    every 3.hours

    def execute(args)
      Pledges.update_patrons! if SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token
    end
  end
end