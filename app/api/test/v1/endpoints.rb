module Test
  module V1
    class Endpoints < Base
      Grape::Middleware::Error.send :include, RespondHelper
      helpers RespondHelper
      version 'v1', using: :path
      format :json

      rescue_from ApiError::Unauthorized do |error|
        code = ApiError.get_code(error)
        generate_error_response(error, code)
      end

      rescue_from :all do |error|
        if error.is_a? ApiError
          code = ApiError.get_code(error)
          generate_error_response(error, code)
        else
          generate_error_response(error, 500)
        end
      end

      namespace 'authentications' do
        mount Token
      end

      namespace 'user' do
        mount User
      end
    end
  end
end
