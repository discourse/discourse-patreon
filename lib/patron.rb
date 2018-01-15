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
            user.custom_fields.except!(*Patreon::USER_DETAIL_FIELDS)
            user.save unless user.custom_fields_clean?
          end
        end
      end
    end

    def self.all
      Patreon.get('users') || {}
    end

    def self.get_local_users_by_patron_ids(ids)
      local_users.select do |user|
        id = user.custom_fields["patreon_id"]
        id.present? && ids.include?(id)
      end
    end

    def self.update_local_user(user, patreon_id, skip_save = false)
      return if user.blank?

      user.custom_fields["patreon_id"] = patreon_id
      user.custom_fields["patreon_email"] = all[patreon_id]["email"]
      user.custom_fields["patreon_amount_cents"] = Patreon::Pledges.all[patreon_id]
      reward_users = Patreon::RewardUser.all
      user.custom_fields["patreon_rewards"] = Patreon::Reward.all.map { |i, r| r["title"] if reward_users[i].include?(patreon_id) }.compact.join(", ")
      user.save unless skip_save || user.custom_fields_clean?
    end

    private

      def self.get_ids_by_rewards(rewards)
        reward_users = Patreon.get('reward-users')

        rewards.map { |id| reward_users[id] }.compact.flatten.uniq
      end

      def self.local_users
        @local_users ||= begin
          users = Patron.all.map do |p|
            patreon_id = p[0]
            patreon_email = p[1]['email']

            user = ::Oauth2UserInfo.find_by(provider: "patreon", uid: patreon_id).try(:user) || ::User.find_by_email(patreon_email)
            update_local_user(user, patreon_id)

            user
          end
          users.compact
        end
      end
  end
end
