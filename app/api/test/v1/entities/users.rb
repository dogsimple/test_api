module Test
  module Entities
    class User < Grape::Entity
      expose :name
    end
  end
end
