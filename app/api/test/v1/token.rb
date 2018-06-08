module Test
  module V1
    class Token < Base
      helpers do
        def authenticate!
          ApiError.raise_error(:Unauthorized, "认证失败!") if !current_user
        end

        def current_user
          @cuttent_user ||= ::User.authorize!(params)
        end
      end
      desc '获取token'
      params do
        requires 'login', type: String
        requires 'password', type: String
      end
      post 'token' do
        authenticate!
        token = OauthToken.create_with_user(current_user)
        generate_success_response({token: token.token_string}, 201)
      end
    end
  end
end

