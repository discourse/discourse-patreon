# name: discourse-patreon
# about: Authenticate with discourse with patreon.com
# version: 0.1
# author: Rafael dos Santos Silva <xfalcox@gmail.com>
# url: https://github.com/xfalcox/discourse-patreon

enabled_site_setting :patreon_client_id
enabled_site_setting :patreon_client_secret

require 'auth/oauth2_authenticator'
require 'omniauth-oauth2'

class PatreonAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    omniauth.provider :patreon,
                      SiteSetting.patreon_client_id,
                      SiteSetting.patreon_client_secret
  end
end

after_initialize do
  class ::OmniAuth::Strategies::Patreon
    option :name, 'patreon'

    option :client_options, {
      :site => 'https://www.patreon.com',
      :authorize_url => 'https://www.patreon.com/oauth2/authorize',
      :token_url => 'https://api.patreon.com/oauth2/token'
    }

    option :authorize_params, {
      :response_type => 'code',
      :client_id => SiteSetting.patreon_client_id,
      :redirect_uri => "#{Discourse.base_url}/auth/patreon/callback"
    }

    option :auth_token_params, {
      :client_id => SiteSetting.patreon_client_id,
      :client_secret => SiteSetting.patreon_client_secret,
      :redirect_uri => "#{Discourse.base_url}/auth/patreon/callback"
    }

    def custom_build_access_token
      verifier = request.params['code']
      client.auth_code.get_token(verifier, options.auth_token_params)
    end

    alias_method :build_access_token, :custom_build_access_token


    uid {
      raw_info['data']['id'].to_s
    }

    info do
      {
        :email => raw_info['data']['attributes']['email'],
        :name => raw_info['data']['attributes']['full_name']
      }
    end

    extra do
      {
        :raw_info => raw_info
      }
    end

    def raw_info
      @raw_info ||= begin
        response = client.request(:get, "https://api.patreon.com/oauth2/api/current_user", :headers => {
            'Authorization' => "Bearer #{access_token.token}"
        }, :parse => :json)
        response.parsed
      end
    end
  end
end

class OmniAuth::Strategies::Patreon < OmniAuth::Strategies::OAuth2
end

auth_provider :title => 'with Patreon',
              :message => 'Authentication with Patreon (make sure pop up blockers are not enabled)',
              :frame_width => 840,
              :frame_height => 570,
              :authenticator => PatreonAuthenticator.new('patreon', trusted: true)

register_css <<CSS

.btn-social.patreon {
    background: transparent url(https://s3.amazonaws.com/patreon_public_assets/toolbox/patreon_logo.png) no-repeat;
    background-position-y: 8px;
    background-position-x: 40px;
    background-size: 15px;
    padding-left: 35px;
    background-color: #232D32;
}

CSS
