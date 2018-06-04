class CreateOauthTokens < ActiveRecord::Migration[5.2]
  def change
    create_table :oauth_tokens do |t|
      t.string :secret_key
      t.integer :user_id

      t.timestamps
    end
  end
end
