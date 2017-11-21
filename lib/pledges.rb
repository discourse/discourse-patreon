require 'json'

module ::Patreon
  class Pledges
    PLUGIN_NAME = 'discourse-patreon'.freeze

    def self.update_patrons!
      update_data
      sync_groups

      rewards = ::PluginStore.get(PLUGIN_NAME, 'rewards')
      ::MessageBus.publish '/patreon/background_sync', rewards
    end

    def self.update_data
      pledges = {}
      rewards = {}
      users = {}
      campaign_rewards = []
      reward_users = {}
      pledges_uris = []

      campaign_data = ::Patreon::Api.campaign_data

      return if campaign_data.blank? || campaign_data['data'].blank?

      campaign_data['data'].map do |campaign|
        pledges_uris << campaign['relationships']['pledges']['links']['first']

        campaign['relationships']['rewards']['data'].each do |entry|
          campaign_rewards << entry['id']
        end
      end

      campaign_data['included'].each do |entry|
        id = entry['id']
        if entry['type'] == 'reward' && campaign_rewards.include?(id)
          rewards[id] = entry['attributes']
          rewards[id]['id'] = id
        end
      end

      pledges_uris.each do |uri|
        pledge_data = ::Patreon::Api.get(uri.sub('page%5Bcount%5D=10', 'page%5Bcount%5D=200'))

        # handle a brand new Patreon with 0 patrons
        break if pledge_data.blank? || pledge_data['data'].blank?

        # get next page if necessary and add to the current loop
        if pledge_data['links'] && pledge_data['links']['next']
          pledges_uris << pledge_data['links']['next']
        end

        # get pledges info
        pledge_data['data'].each do |entry|
          if entry['type'] == 'pledge'
            declined_since = entry['attributes']['declined_since']
            if declined_since.present?
              declined_days_count = Time.now.to_date - declined_since.to_date
              next unless declined_days_count < SiteSetting.patreon_declined_pledges_grace_period_days
            end

            (reward_users[entry['relationships']['reward']['data']['id']] ||= []) << entry['relationships']['patron']['data']['id'] unless entry['relationships']['reward']['data'].nil?
            pledges[entry['relationships']['patron']['data']['id']] = entry['attributes']['amount_cents']
          end
        end

        # get user list too
        pledge_data['included'].each do |entry|
          case entry['type']
          when 'user'
            users[entry['id']] = { email: entry['attributes']['email'].downcase }
          end
        end
      end

      # Special catch all patrons virtual reward
      rewards['0']['title'] = 'All Patrons'
      rewards['0']['amount_cents'] = 0
      reward_users['0'] = pledges.keys

      ::PluginStore.set(PLUGIN_NAME, 'pledges', pledges)
      ::PluginStore.set(PLUGIN_NAME, 'rewards', rewards)
      ::PluginStore.set(PLUGIN_NAME, 'users', users)
      ::PluginStore.set(PLUGIN_NAME, 'reward-users', reward_users)

      # Sets all patrons to the seed group by default on first run
      filters = PluginStore.get(PLUGIN_NAME, 'filters')
      Patreon::Seed.seed_content! if filters.nil?
    end

    def self.sync_groups
      filters = (PluginStore.get(PLUGIN_NAME, 'filters') || {})

      filters.each_pair do |group_id, rewards|

        group = Group.find_by(id: group_id)

        next if group.nil?

        patreon_users = find_user_by_rewards(rewards)

        next if patreon_users.nil? || patreon_users.empty?

        users = patreon_users_to_discourse_users(patreon_users)

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

    private

    def self.find_user_by_rewards(rewards)
      reward_users = ::PluginStore.get(PLUGIN_NAME, 'reward-users')

      rewards.map { |id| reward_users[id] }.compact.flatten.uniq
    end

    def self.patreon_users_to_discourse_users(patreon_users_ids)
      users = ::PluginStore.get(PLUGIN_NAME, 'users')

      discourse_users = patreon_users_ids.map do |id|
        ::Oauth2UserInfo.find_by(provider: "patreon", uid: id).try(:user) || User.find_by_email(users[id]['email'])
      end
      discourse_users.compact
    end

  end
end
