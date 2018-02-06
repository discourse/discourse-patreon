module ::Jobs
  class PatreonSyncPatronsToGroups < ::Jobs::Scheduled
    every 6.hours
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token

      ::Patreon::Patron.update!
      ::Patreon.set("last_sync", at: Time.now)
    end
  end
end
