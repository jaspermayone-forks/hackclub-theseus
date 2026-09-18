class AddActiveToUSPSPaymentAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :usps_payment_accounts, :active, :boolean, default: true, null: false
  end
end
