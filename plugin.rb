# name: discourse-patreon
# about: Integration features between Patreon and Discourse
# version: 0.2
# author: Rafael dos Santos Silva <xfalcox@gmail.com>
# url: https://github.com/xfalcox/discourse-patreon

gem 'patreon', '0.2.0', require: false

require 'auth/oauth2_authenticator'
require 'omniauth-oauth2'

enabled_site_setting :patreon_enabled

PLUGIN_NAME = 'discourse-patreon'.freeze

register_asset 'stylesheets/patreon.scss'

after_initialize do

  require_dependency 'admin_constraint'

  unless ::PluginStore.get(PLUGIN_NAME, 'not_first_time')
    ::PluginStore.set(PLUGIN_NAME, 'not_first_time', true)

    # seed

    group = Group.new(
      name: 'Patrons',
      visible: true,
      primary_group: true,
      title: 'Patron',
      flair_url: 'https://www.patreon.com/images/patreon_navigation_logo_mini_orange.png',
      bio_raw: 'To get access to this group go to our [Patreon page](https://www.patreon.com/) and add your pledge.',
      full_name: 'Our Patreon supporters'
    )
    group.save

    badge = Badge.new(
      name: 'Patron',
      description: 'Active Patron',
      badge_type_id: 1,
      icon: 'https://www.patreon.com/images/patreon_navigation_logo_mini_orange.png',
      listable: true,
      target_posts: false,
      query: "select user_id, created_at granted_at, NULL post_id from group_users where group_id = ( select g.id from groups g where g.name = 'Patrons' )",
      enabled: true,
      auto_revoke: true,
      badge_grouping_id: 2,
      trigger: 0,
      show_posts: false,
      system: false,
      image: 'https://www.patreon.com/images/patreon_navigation_logo_mini_orange.png',
      long_description: 'To get access to this badge go to our [Patreon page](https://www.patreon.com/) and add your pledge.'
    )
    badge.save


    # seed
  end

  module ::Patreon
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Patreon
    end
  end

  load File.expand_path('../app/controllers/patreon_admin_controller.rb', __FILE__)
  load File.expand_path('../app/controllers/patreon_webhook_controller.rb', __FILE__)
  load File.expand_path('../app/jobs/scheduled/sync_patrons_to_groups.rb', __FILE__)
  load File.expand_path('../app/jobs/scheduled/update_tokens.rb', __FILE__)
  load File.expand_path('../lib/pledges.rb', __FILE__)
  load File.expand_path('../lib/tokens.rb', __FILE__)

  Patreon::Engine.routes.draw do
    get '/rewards' => 'patreon_admin#rewards', constraints: AdminConstraint.new
    get '/list' => 'patreon_admin#list', constraints: AdminConstraint.new
    post '/list' => 'patreon_admin#edit', constraints: AdminConstraint.new
    delete '/list' => 'patreon_admin#delete', constraints: AdminConstraint.new
    post '/webhook' => 'patreon_webhook#index'
  end

  Discourse::Application.routes.prepend do
    mount ::Patreon::Engine, at: '/patreon'
  end

  add_admin_route 'patreon.title', 'patreon'

  Discourse::Application.routes.append do
    get '/admin/plugins/patreon' => 'admin/plugins#index'
    get '/admin/plugins/patreon/list' => 'patreon_admin#list'
  end

  class ::OmniAuth::Strategies::Patreon
    option :name, 'patreon'

    option :client_options, {
      site: 'https://www.patreon.com',
      authorize_url: 'https://www.patreon.com/oauth2/authorize',
      token_url: 'https://api.patreon.com/oauth2/token'
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

# Authentication with Patreon
class OmniAuth::Strategies::Patreon < OmniAuth::Strategies::OAuth2
end

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

auth_provider title: 'with Patreon',
              message: 'Authentication with Patreon (make sure pop up blockers are not enabled)',
              frame_width: 840,
              frame_height: 570,
              authenticator: PatreonAuthenticator.new('patreon', trusted: true)

