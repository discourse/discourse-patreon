# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :products do |t|
      t.string :type
      t.string :external_id, null: false
    end

    add_index :products, [:type, :external_id], unique: true
  end
end
