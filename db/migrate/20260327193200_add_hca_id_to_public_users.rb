class AddHcaIdToPublicUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :public_users, :hca_id, :string
    add_index :public_users, :hca_id, unique: true
  end
end
