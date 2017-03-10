require 'patreon'
require 'json'

module ::Patreon
  class Pledges
    PLUGIN_NAME = 'discourse-patreon'.freeze

    def self.update_patrons!
      update_data
      sync_groups
    end

    def self.update_data
      pledges = []
      rewards = []

      conn = Faraday.new(url: 'https://api.patreon.com',
                         headers: { 'Authorization' => "Bearer #{SiteSetting.patreon_creator_access_token}" })

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
            pledges << entry
          elsif entry['type'] == 'reward'
            rewards << entry
          end
        end
      end

      ::PluginStore.set(PLUGIN_NAME, 'pledges', pledges.to_json)
      ::PluginStore.set(PLUGIN_NAME, 'rewards', rewards.to_json)
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
end
