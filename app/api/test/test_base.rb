require 'grape-swagger'
class TestBase < Grape::API
  mount Test::V1::Endpoints
end
