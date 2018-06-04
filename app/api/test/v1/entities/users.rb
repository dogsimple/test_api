module Test
  module Entities
    class Users < Grape::Entity
      expose :name
    end
  end
end
