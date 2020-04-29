# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :subscriptions do |t|
      t.string :type
      t.string :external_id, null: false
      t.references :customer, index: true, foreign_key: true, null: false
      t.references :plan, index: true, foreign_key: true, null: false
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.datetime :last_payment_at
      t.string :last_payment_status
      t.decimal :total_amount, precision: 8, scale: 2, null: false, default: 0
      t.integer :status, index: true, null: false
      t.timestamps
    end

    add_index :subscriptions, [:type, :external_id], unique: true
  end
end
