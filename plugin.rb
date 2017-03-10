# name: discourse-patreon
# about: Authenticate with discourse with patreon.com, and sync patrons to a group
# version: 0.2
# author: Rafael dos Santos Silva <xfalcox@gmail.com>
# url: https://github.com/xfalcox/discourse-patreon

gem 'patreon', '0.2.0', require: false

enabled_site_setting :patreon_client_id
enabled_site_setting :patreon_client_secret

require 'auth/oauth2_authenticator'
require 'omniauth-oauth2'
require 'patreon'

PLUGIN_NAME = 'discourse-patreon'.freeze

class PatreonAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    omniauth.provider :patreon,
                      SiteSetting.patreon_client_id,
                      SiteSetting.patreon_client_secret
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    ::PluginStore.set('patreon', "login_user_#{user.id}", patreon_id: data[:uid])
  end
end

after_initialize do

  unless ::PluginStore.get(PLUGIN_NAME, "not_first_time")
    ::PluginStore.set(PLUGIN_NAME, "not_first_time", true)
    #::PluginStore.set(PLUGIN_NAME, "category_*", [{ category_id: '0', channel: "#general", filter: "follow" }])
    # seed
  end

  module ::Patreon
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Patreon
    end
  end

  load File.expand_path('../app/controllers/patreon_controller.rb', __FILE__)
  load File.expand_path('../app/jobs/scheduled/sync_patrons_to_groups.rb', __FILE__)
  load File.expand_path('../app/jobs/scheduled/update_tokens.rb', __FILE__)
  load File.expand_path('../lib/pledges.rb', __FILE__)
  load File.expand_path('../lib/tokens.rb', __FILE__)

  class ::OmniAuth::Strategies::Patreon
    option :name, 'patreon'

    option :client_options, {
      :site => 'https://www.patreon.com',
      :authorize_url => 'https://www.patreon.com/oauth2/authorize',
      :token_url => 'https://api.patreon.com/oauth2/token'
    }

    option :authorize_params, {
      response_type: 'code',
      client_id: SiteSetting.patreon_client_id,
      redirect_uri: "#{Discourse.base_url}/auth/patreon/callback"
    }

    option :auth_token_params, {
      client_id: SiteSetting.patreon_client_id,
      client_secret: SiteSetting.patreon_client_secret,
      redirect_uri: "#{Discourse.base_url}/auth/patreon/callback"
    }

    def custom_build_access_token
      verifier = request.params['code']
      client.auth_code.get_token(verifier, options.auth_token_params)
    end

    alias build_access_token custom_build_access_token


    uid {
      raw_info['data']['id'].to_s
    }

    info do
      {
        email: raw_info['data']['attributes']['email'],
        name: raw_info['data']['attributes']['full_name']
      }
    end

    extra do
      {
        :raw_info => raw_info
      }
    end

    def raw_info
      @raw_info ||= begin
        response = client.request(
          :get,
          'https://api.patreon.com/oauth2/api/current_user',
          headers: {
            'Authorization' => "Bearer #{access_token.token}"
          },
          parse: :json
        )
        response.parsed
      end
    end
  end

  add_admin_route "patreon.title", "patreon"

  Discourse::Application.routes.append do
    get "/admin/plugins/patreon" => "admin/plugins#index"
    get "/admin/plugins/patreon/list" => "patreon#list"
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
