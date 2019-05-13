# frozen_string_literal: true

module ::Jobs
  class PatreonUpdateTokens < ::Jobs::Scheduled
    every 7.days

    def execute(args)
      ::Patreon::Tokens.update! if SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token
    end
  end
end
