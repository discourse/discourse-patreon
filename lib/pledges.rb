module ::Patreon
  class Pledges

    def self.create!(pledge_data)
      save!([pledge_data], true)
    end

    def self.update!(pledge_data)
      delete!(pledge_data)
      create!(pledge_data)
    end

    def self.delete!(pledge_data)
      rel = pledge_data['data']['relationships']
      patron_id = rel['patron']['data']['id']
      reward_id = rel['reward']['data']['id'] unless rel['reward']['data'].blank?

      pledges = all.except(patron_id)
      patrons = Patreon::Patron.all.except(patron_id)
      reward_users = Patreon::RewardUser.all
      reward_users[reward_id].reject! { |i| i == patron_id } if reward_id.present?

      Patreon.set("pledges", pledges)
      Patreon.set("users", patrons)
      Patreon.set("reward-users", reward_users)
    end

    def self.pull!(uris)
      pledges_data = []

      uris.each do |uri|
        pledge_data = ::Patreon::Api.get(uri)

        # get next page if necessary and add to the current loop
        if pledge_data['links'] && pledge_data['links']['next']
          next_page_uri = pledge_data['links']['next']
          uris << next_page_uri if next_page_uri.present?
        end

        pledges_data << pledge_data if pledge_data.present?
      end

      save!(pledges_data)
    end

    def self.save!(pledges_data, is_append = false)
      pledges = is_append ? all : {}
      reward_users = is_append ? Patreon::RewardUser.all : {}
      users = is_append ? Patreon::Patron.all : {}

      pledges_data.each do |pledge_data|
        new_pledges, new_reward_users, new_users = extract(pledge_data)

        pledges.merge!(new_pledges)
        reward_users.merge!(new_reward_users)
        users.merge!(new_users)
      end

      reward_users['0'] = pledges.keys

      Patreon.set('pledges', pledges)
      Patreon.set('reward-users', reward_users)
      Patreon.set('users', users)
    end

    def self.extract(pledge_data)
      return if pledge_data.blank? || pledge_data["data"].blank?

      pledges = {}
      reward_users = {}
      users = {}

      pledge_data['data'] = [pledge_data['data']] unless pledge_data['data'].kind_of?(Array)

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

      return pledges, reward_users, users
    end

    def self.all
      Patreon.get('pledges') || {}
    end
  end
end
