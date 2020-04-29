# frozen_string_literal: true

class SubscriptionSerializer < ApplicationSerializer
  attributes :type,
             :external_id,
             :amount,
             :last_payment_at,
             :last_payment_status,
             :total_amount,
             :status,
             :created_at

  has_one :plan, serializer: ::PlanSerializer, embed: :objects

end
