module Test
  module V1
    class Base < Grape::API
      before do
        Rails.logger.debug "===> params is: #{params.inspect}\n===> headers is: #{headers.inspect}"
      end
    end
  end
end
