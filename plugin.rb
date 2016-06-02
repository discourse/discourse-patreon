# name: discourse-patreon
# about: Authenticate with discourse with patreon.com, and sync patrons to a group
# version: 0.2
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

  def after_create_account(user, auth)
    data = auth[:extra_data]
    ::PluginStore.set('patreon', "user_#{user.id}", {patreon_id: data[:uid] })
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

  module ::Patreon
    class SyncPatronsToGroups < ::Jobs::Scheduled
      every 3.hours

      def execute(args)
        Pledges.update_patrons! if SiteSetting.patreon_creator_access_token && SiteSetting.patreon_sync_patrons_to_group
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


class Pledges

  def self.update_patrons!
    pledges = get_pledges
    users = pledges_to_users pledges
    group = get_group
    sync_group!(group, users)
  end

  def self.get_pledges
    pledges = []

    conn = Faraday.new( url: 'https://api.patreon.com',
                        headers: {'Authorization' => "Bearer #{SiteSetting.patreon_creator_access_token}"}
    )

    campaign_response = conn.get '/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges'
    campaign_data = JSON.parse campaign_response.body

    pledges_uris = campaign_data['data'].map do |campaign|
      campaign['relationships']['pledges']['links']['first']
    end

    pledges_uris.each do |uri|
      request = conn.get(uri.sub('https://api.patreon.com', ''))
      pledge_data = JSON.parse request.body

      if pledge_data['links']['next']
        pledges_uris << pledges_data['links']['next']
      end

      pledge_data['included'].each do |entry|
        if entry['type'] == 'user'
          pledges << entry['attributes']['email']
        end
      end
    end

    pledges
  end

  def self.pledges_to_users(pledges)
    mails = pledges.map do |email|
      User.find_by_email email
    end
    mails.compact
  end

  def self.get_group
    Group.find_by_name SiteSetting.patreon_sync_patrons_to_group
  end

  def self.sync_group!(group, users)
    group.transaction do
      (users - group.users).each do |user|
        group.add user
      end

      (group.users - users).each do |user|
        group.remove user
      end
    end
  end
end

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
