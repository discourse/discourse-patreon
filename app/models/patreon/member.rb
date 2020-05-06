# frozen_string_literal: true

module ::Patreon
  class Member < ::Subscription
    API_FIELDS = %W{
      full_name
      email
      last_charge_date
      last_charge_status
      lifetime_support_cents
      currently_entitled_amount_cents
      patron_status
      pledge_relationship_start
    }

    def self.get_patreon_id(data)
      data&.dig("relationships", "user", "data", "id")
    end

    def self.update(data, included = [])
      data.each do |object|
        external_id = get_patreon_id(object)
        attrs = object["attributes"]

        status =
          case attrs["patron_status"]
          when nil then :new
          when "active_patron" then :active
          when "declined_patron" then :pending
          when "former_patron" then :inactive
          end

        email = attrs["email"]
        email ||= begin
          value = nil

          included.each do |i|
            next unless i["type"] == "user" && i["id"] = external_id
            value = i.dig("attributes", "email")
          end

          value
        end

        Member.where(external_id: external_id).first_or_initialize.tap do |m|
          m.amount = attrs["currently_entitled_amount_cents"].to_i / 100
          m.last_payment_at = attrs["last_charge_date"]
          m.last_payment_status = attrs["last_charge_status"]
          m.total_amount = attrs["lifetime_support_cents"].to_i / 100
          m.status = Member.statuses[status]
          m.created_at = attrs["pledge_relationship_start"]
          current_tiers = object&.dig("relationships", "currently_entitled_tiers", "data") || []
          tier_id = current_tiers[0]["id"] if current_tiers.present?
          m.plan = Tier.find_by(external_id: tier_id)
          m.find_or_initialize_customer(email)

          m.customer.tap do |c|
            c.name = attrs["full_name"]
            c.total_amount = m.total_amount
            c.status = m.status if c.status.blank? || c.status > m.status
            c.save! if c.changed?
          end

          m.save! if m.changed?
          m.sync_groups
        end
      end
    end

    def sync_groups
      super

      user = customer.user
      return if user.blank?

      is_member = true

      case status
      when Subscription.statuses[:inactive]
        is_member = false
      when Subscription.statuses[:pending]
        grace_period = SiteSetting.patreon_declined_pledges_grace_period_days
        is_member = (last_payment_at > (1.month + grace_period.days).ago)
      end

      group = Patreon.default_group
      is_existing_member = GroupUser.exists?(group: group, user: user)

      if is_member && !is_existing_member
        group.add user
      elsif !is_member && is_existing_member
        group.remove user
      end
    end

    def find_user(email)
      user = User
        .joins(:oauth2_user_infos)
        .find_by("oauth2_user_infos.provider": "patreon", "oauth2_user_infos.uid": external_id)
      user ||= User
        .joins(:_custom_fields)
        .find_by("user_custom_fields.name": "patreon_id", "user_custom_fields.value": external_id)
      user ||= super
      user
    end

    def self.sync_groups
      super

      grace_period = SiteSetting.patreon_declined_pledges_grace_period_days

      users = User
        .joins(:subscriptions)
        .where("subscriptions.type": "Patreon::Member")
        .where("subscriptions.status <= ?
                OR (subscriptions.status = ? AND subscriptions.last_payment_at > ?)",
                Subscription.statuses[:new], Subscription.statuses[:pending], grace_period.ago)

      sync(Patreon.default_group, users)
    end

  end
end
