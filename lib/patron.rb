require 'json'

module ::Patreon
  class Patron

    def self.update!
      return unless Patreon::Campaign.update!
      sync_groups

      rewards = Patreon.get('rewards')
      ::MessageBus.publish '/patreon/background_sync', rewards
    end

    def self.sync_groups
      filters = Patreon.get('filters') || {}
      return if filters.blank?

      local_users = get_local_users

      filters.each_pair do |group_id, rewards|
        group = Group.find_by(id: group_id)

        next if group.nil?

        reward_users = Patreon::RewardUser.all
        patron_ids = rewards.map { |id| reward_users[id] }.compact.flatten.uniq

        next if patron_ids.blank?

        users = local_users.select do |user|
          id = user.custom_fields["patreon_id"]
          is_declined = false
          declined_since = Patreon::Pledge::Decline.all[id]

          if declined_since.present?
            declined_days_count = Time.now.to_date - declined_since.to_date
            is_declined = declined_days_count > SiteSetting.patreon_declined_pledges_grace_period_days
          end

          id.present? && patron_ids.include?(id) && !is_declined
        end

        (users - group.users).each do |user|
          group.add user
        end

        (group.users - users).each do |user|
          group.remove user
        end
      end
    end

    def self.all
      Patreon.get('users') || {}
    end

    def self.update_local_user(user, patreon_id, skip_save = false)
      return if user.blank?

      user.custom_fields["patreon_id"] = patreon_id
      user.save unless skip_save || user.custom_fields_clean?

      user
    end

    def self.attr(name, user)
      id = user.custom_fields['patreon_id']
      return if id.blank?

      case name
      when "email"
        all[id]
      when "amount_cents"
        Patreon::Pledge.all[id]
      when "rewards"
        reward_users = Patreon::RewardUser.all
        Patreon::Reward.all.map { |i, r| r["title"] if reward_users[i].include?(id) }.compact.join(", ")
      when "declined_since"
        Patreon::Pledge::Decline.all[id]
      else
        id
      end
    end

    def self.get_local_users
      users = User.joins(:_custom_fields).where(user_custom_fields: { name: 'patreon_id' }).uniq
      patrons = all.slice!(*UserCustomField.where(name: 'patreon_id').where("value IS NOT NULL").pluck(:value))

      oauth_users = Oauth2UserInfo.includes(:user).where(provider: "patreon")
      oauth_users = oauth_users.where("uid IN (?)", patrons.keys) if patrons.present?

      users += oauth_users.map do |o|
        patrons = patrons.slice!(o.uid)
        update_local_user(o.user, o.uid)
      end

      emails = patrons.values.map { |e| e.downcase }
      users += UserEmail.includes(:user).where(email: emails).map do |u|
        patreon_id = patrons.key(u.email)
        update_local_user(u.user, patreon_id)
      end

      users.compact
    end

  end
end
