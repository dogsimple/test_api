desc "api 路由"
task :api_routes => :environment do
  TestBase.routes.each do |api|

    prefix = '/api/test'
    method = api.route_method.ljust(10)
    path = api.route_path
    puts "#{method} #{prefix} #{path}"
  end
end
