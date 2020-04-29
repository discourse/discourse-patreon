# frozen_string_literal: true

class Customer < ActiveRecord::Base
  belongs_to :user, inverse_of: :customer
  has_many :subscriptions, dependent: :destroy

  ADMIN_DETAILED_USER_FIELDS = %W{
    full_name
    email
    last_charge_date
    last_charge_status
    lifetime_support_cents
    currently_entitled_amount_cents
    patron_status
    pledge_relationship_start
  }

  def self.statuses
    @statuses ||= Enum.new(active: 1,
                           new: 2,
                           pending: 3,
                           inactive: 4
                          )
  end
end
