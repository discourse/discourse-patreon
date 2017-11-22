require 'json'

module ::Patreon
  class Patron

    def self.update!
      Patreon::Campaign.update!
      sync_groups

      rewards = Patreon.get('rewards')
      ::MessageBus.publish '/patreon/background_sync', rewards
    end

    def self.sync_groups
      filters = (Patreon.get('filters') || {})

      filters.each_pair do |group_id, rewards|
        group = Group.find_by(id: group_id)

        next if group.nil?

        patron_ids = get_ids_by_rewards(rewards)

        next if patron_ids.blank?

        users = get_local_users_by_patron_ids(patron_ids)

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

    def self.all
      Patreon.get('users') || {}
    end

    private

      def self.get_ids_by_rewards(rewards)
        reward_users = Patreon.get('reward-users')

        rewards.map { |id| reward_users[id] }.compact.flatten.uniq
      end

      def self.get_local_users_by_patron_ids(ids)
        users = ::Patreon.get('users')

        local_users = ids.map do |id|
          ::Oauth2UserInfo.find_by(provider: "patreon", uid: id).try(:user) || ::User.find_by_email(users[id]['email'])
        end
        local_users.compact
      end
  end
end
