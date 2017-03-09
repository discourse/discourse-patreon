require 'patreon'

module ::Patreon
  class Pledges
    def self.update_patrons!
      pledges = get_pledges
      users = pledges_to_users pledges
      group = get_group
      sync_group!(group, users)
    end

    def self.get_pledges
      pledges = []

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
          pledges << entry['attributes']['email'] if entry['type'] == 'user'
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
end
