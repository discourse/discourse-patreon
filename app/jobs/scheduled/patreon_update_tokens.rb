module ::Patreon
  class UpdateTokens < ::Jobs::Scheduled
    every 7.days

    def execute(args)
      Tokens.update! if SiteSetting.patreon_creator_access_token && SiteSetting.patreon_creator_refresh_token
    end
  end
end