module ::Jobs
  class PatreonSyncPatronsToGroups < ::Jobs::Scheduled
    every 6.hours
    sidekiq_options retry: false

    def execute(args)
      ::Patreon::Patron.update! if SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token
    end
  end
end
