module Test
  module V1
    class User < Base
      desc "ger current user profile" do
        failure [{code:401,message:'Unauthorized'}]
      end
      get 'user_profile' do
        token = request.headers['Http-X-Authentication-Token']
        ApiError.raise_error(:Unauthorized, "认证失败!") if token.blank?
        raw_data = Base64.decode64(token).split('::')
        # raw_data = [<user id>, <timestamo>, <签名>]
        @user = ::User.find_by_id(raw_data[0])
        ApiError.raise_error(:Unauthorized, "认证失败!") if @user.nil?
        oauth_token = OauthToken.where(user_id: @user.id).order('created_at DESC').first
        ApiError.raise_error(:Unauthorized, "认证失败!") if oauth_token.nil?
        service_token = oauth_token.generate_token(raw_data[0..1])
        ApiError.raise_error(:Unauthorized, "认证失败!") if token != service_token
        generate_success_response({id: @user.id, name: @user.name}, 200)
      end
    end
  end
end
