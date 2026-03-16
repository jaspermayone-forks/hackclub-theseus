class AddInvalidatedAtToHCBOauthConnections < ActiveRecord::Migration[8.0]
  def change
    add_column :hcb_oauth_connections, :invalidated_at, :datetime
  end
end
