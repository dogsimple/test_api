module Test
  module V1
    class Endpoints < Base
      helpers RespondHelper
      version 'v1', using: :path
      format :json
      content_type :xml, 'application/xml'
      content_type :json, 'application/json'
      content_type :txt, 'text/plain'
      content_type :txt, 'text/xml'

      rescue_from :all do |error|
        if error.class.to_s.include?("ApiError")
          code = ApiError.get_code(error)
          msg = generate_error_response(error, code)
          error!(msg, code)
        else
          msg = generate_error_response(error, 500)
          error!(msg, 500)
        end
      end

      namespace 'authentications' do
        mount Token
      end

      namespace 'user' do
        mount User
      end

      add_swagger_documentation(
        base_path: '/api/test/',
        :api_version=> "v1",
        hide_documentation_path: true,
      )
    end
  end
end
