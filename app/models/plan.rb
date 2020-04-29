# frozen_string_literal: true

class Plan < ActiveRecord::Base
  belongs_to :product
  has_many :subscriptions
end
