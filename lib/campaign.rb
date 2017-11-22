require 'json'

module ::Patreon
  class Campaign

    def self.update!
      rewards = {}
      campaign_rewards = []
      pledges_uris = []

      response = ::Patreon::Api.campaign_data

      return if response.blank? || response['data'].blank?

      response['data'].map do |campaign|
        uri = campaign['relationships']['pledges']['links']['first']
        pledges_uris << uri.sub('page%5Bcount%5D=10', 'page%5Bcount%5D=200')

        campaign['relationships']['rewards']['data'].each do |entry|
          campaign_rewards << entry['id']
        end
      end

      response['included'].each do |entry|
        id = entry['id']
        if entry['type'] == 'reward' && campaign_rewards.include?(id)
          rewards[id] = entry['attributes']
          rewards[id]['id'] = id
        end
      end

      Patreon::Pledges.pull!(pledges_uris)

      # Special catch all patrons virtual reward
      rewards['0']['title'] = 'All Patrons'
      rewards['0']['amount_cents'] = 0

      Patreon.set('rewards', rewards)

      # Sets all patrons to the seed group by default on first run
      filters = Patreon.get('filters')
      Patreon::Seed.seed_content! if filters.nil?
    end

  end
end
