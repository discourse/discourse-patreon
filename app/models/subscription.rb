# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  belongs_to :customer
  belongs_to :plan

  def self.statuses
    @statuses ||= Enum.new(active: 1,
                           new: 2,
                           pending: 3,
                           inactive: 4
                          )
  end

  def find_or_initialize_customer(email)
    return if self.customer&.user&.present?

    user = find_user(email)

    if self.customer.blank?
      self.customer = user.customer if user&.customer&.present?

      emails = [email]
      emails += user.emails if user.present?

      self.customer ||= Customer.where(email: emails).first
      self.customer ||= Customer.new(email: email)
    end

    self.customer.user ||= user
  end

  def find_user(email)
    User.with_email(email).first
  end

  def sync_groups
    filters = Patreon.get('filters') || {}
    return if filters.blank?

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

    filters.each_pair do |group_id, plan_ids|
      group = Group.find_by(id: group_id)
      next if group.blank?

      is_member = false if is_member && plan_ids.exclude?(plan_id)
      is_existing_member = GroupUser.exists?(group: group, user: user)

      if is_member && !is_existing_member
        group.add user
      elsif !is_member && is_existing_member
        group.remove user
      end
    end
  end

  def self.sync_groups
    filters = Patreon.get('filters') || {}
    return if filters.blank?

    grace_period = 1.month + SiteSetting.patreon_declined_pledges_grace_period_days.days

    filters.each_pair do |group_id, plan_ids|
      group = Group.find_by(id: group_id)
      next if group.blank?

      users = User
        .joins(:subscriptions)
        .where("subscriptions.plan_id": plan_ids)
        .where("subscriptions.status <= ?
                OR (subscriptions.status = ? AND subscriptions.last_payment_at > ?)",
                Subscription.statuses[:new], Subscription.statuses[:pending], grace_period.ago)

      sync(group, users)
    end
  end

  protected
  def self.sync(group, users)
    user_ids = users.pluck(:id)
    group_user_ids = GroupUser.where(group: group).pluck(:user_id)

    users.where.not(id: group_user_ids).each do |user|
      group.add user
    end

    User.where(id: (group_user_ids - user_ids)).each do |user|
      group.remove user
    end
  end

end
