class CreateSberbankTransactions < ActiveRecord::Migration
  def change
    create_table :spree_sberbank_transactions do |t|
      t.integer :payment_method_id
      t.string :registered_order_id
      t.string :transaction_order_number
      t.string  :form_url
      t.timestamps null: true
      t.belongs_to :spree_order, index: true, unique: true
    end
  end
end
