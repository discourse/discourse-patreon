require 'patreon'

module ::Patreon
  class Tokens
    def self.update!
      redirect_uri = "#{Discourse.base_url}/auth/patreon/callback"

      oauth_client = Patreon::OAuth.new(SiteSetting.patreon_client_id, SiteSetting.patreon_client_secret)
      tokens = oauth_client.refresh_token(SiteSetting.patreon_creator_refresh_token, redirect_uri)

      SiteSetting.patreon_creator_access_token = tokens['access_token']
      SiteSetting.patreon_creator_refresh_token = tokens['refresh_token']
    end
  end
end
