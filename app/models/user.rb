class User < ApplicationRecord
  has_secure_password

  def self.authorize!(params)
    name = params[:login]
    password = params[:password]
    @user = User.find_by_name(name).try(:authenticate, password)
  end
end
