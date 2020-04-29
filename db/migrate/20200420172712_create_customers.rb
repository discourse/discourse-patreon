# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[6.0]
  def change
    create_table :customers do |t|
      t.references :user, index: { unique: true }, foreign_key: true
      t.string :name
      t.string :email, limit: 513, index: { unique: true }
      t.decimal :total_amount, precision: 8, scale: 2, null: false, default: 0
      t.integer :status, index: true, null: false
      t.timestamps
    end
  end
end
