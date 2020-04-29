# frozen_string_literal: true

class CreatePlans < ActiveRecord::Migration[6.0]
  def change
    create_table :plans do |t|
      t.string :type
      t.string :external_id, null: false
      t.references :product, index: true, foreign_key: true, null: false
      t.string :name, null: false
      t.decimal :amount, precision: 8, scale: 2, null: false
    end

    add_index :plans, [:type, :external_id], unique: true
  end
end
