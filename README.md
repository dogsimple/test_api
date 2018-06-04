#### 安装
```ruby
gem 'grape'
budnle install
```
#### 基本用法

```ruby
module Test
  class API < Grape::API
    version 'v1', using: :path
    format :json

    helpers do
      def current_user
        @current_user ||= User.authorize!(env)
      end

      def authenticate!
        error!('401 Unauthorized', 401) unless current_user
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
```
#### 装载
##### rails
新增app/api文件夹
```shell
$ mkdir app/api/
```
创建api_base文件`Test::V1::Base`对应路径为`app/api/test/v1/base.rb`
修改`application.rb`文件
```ruby
config.paths.add File.join('app', 'api'), glob: File.join('**', '*.rb')
config.autoload_paths += Dir[Rails.root.join('app', 'api', '*')]
```
修改路由
```ruby
mount Test::Base => '/api/test'
```
##### modules
在一个应用中你可以mount多个其他应用的api
```ruby
class Twitter::API < Grape::API
  mount Twitter::APIv1
  mount Twitter::APIv2
end
```
你也可以挂到一个路径上
```ruby
class Twitter::API < Grape::API
  mount Twitter::APIv1 => '/v1'
end
```
注意像`before/after/rescue_from`的声明必须放在`mount`之前以方便他们被继承
```ruby
class Twitter::API < Grape::API
  before do
    header 'X-Base-Header', 'will be defined for all APIs that are mounted below'
  end

  mount Twitter::Users
  mount Twitter::Search
end
```
##### 版本控制
有四种方式提供api的版本,`:path, :header, :accept_version_header, :param`,默认的方式是`：path`
##### Path
```ruby
version 'v1',  using::path
```

用这种版本控制方式,客户端应该在url中加入版本信息
```ruby
curl http://localhost:9292/v1/statuses/public_timeline
```
##### header
```ruby
version 'v1', using: :header, vendor: 'twitter'
```
现在,grape只支持如下格式
```ruby
vnd.vendor-and-or-resource-v1234+format
```
-和+之间的信息就会被理解为版本信息
使用这种方式,客户端必须在`HTTP Accept head`中传递版本信息
```ruby
curl -H Accept:application/vnd.twitter-v1+json http://localhost:9292/statuses/public_timeline
```
默认情况下,当没有传递`Accept`header信息时,将使用第一个匹配的版本,要改变这种默认行为可以使用`:strict` option.当它的值为`true`时,这种情况会返回`406 Not Acceptable`错误
当提供了一个无效的Accept头时，如果`:cascade`选项设置为false，会返回一个406错误,否则，如果没有其他的路径匹配,会返回一个404错误
##### Accept-Version Header
```ruby
version 'v1', using: :accept_version_header
```
使用这种方式,客户端必须在HTTP`Accept-Version`header中传递版本信息
```ruby
curl -H "Accept-Version:v1" http://localhost:9292/statuses/public_timeline
```
默认情况与header方式一致
##### Param
```ruby
version 'v1', using: :param
```
使用这种方式,客户端需要传递版本信息在parameter中
```ruby
curl http://localhost:9292/statuses/public_timeline?apiver=v1
```
默认情况,参数名为'apiver',修改可以使用`:parameter`选项
```ruby
version 'v1', using: :param, parameter: 'v'
```
```ruby
curl http://localhost:9292/statuses/public_timeline?v=v1
```
##### 描述方法
你可以将描述添加到api方法和namespace
```ruby
desc 'Returns your public timeline.' do
  detail 'more details'
  params  API::Entities::Status.documentation
  success API::Entities::Entity
  failure [[401, 'Unauthorized', 'Entities::Error']]
  named 'My named route'
  headers XAuthToken: {
            description: 'Validates your identity',
            required: true
          },
          XOptionalHeader: {
            description: 'Not really needed',
            required: false
          }

end
get :public_timeline do
  Status.limit(20)
end
```

- `detail`:一个更加详细的描述
- `params`:确定参数来源于`Entity`
- `success`:
- `failure`:失败的HTTP Codes和Entities
- `named`: 给路由一个名称,方便在文档中查找
- `headers`:定义有效的heades
##### paramters
请求可以的参数,通过`params`hash对象,包括`GET`,`POST`,`PUT`,当然也可以在路由中指定参数名
```ruby
get :public_timeline do
  Status.order(params[:sort_by])
end
```
对于form表单,json和xml paramter是从请求body中自动填充,当使用`put`,`post`方法时
请求
```ruby
curl -d '{"text": "140 characters"}' 'http://localhost:9292/statuses' -H Content-Type:application/json -v
```
grape 端口
```ruby
post '/statuses' do
  Status.create!(text: params[:text])
end
```
Mutipart posts/puts也同样支持
```ruby
curl --form image_file='@image.jpg;type=image/jpg' http://localhost:9292/upload
```
grape 端口
```ruby
post 'upload' do
  # file in params[:image_file]
end
```
在以下2者有冲突的情况下
- 路由字符串参数
- `get`, `Post`, `put`
-  请求内容

路由字符串参数有最高优先级
##### Params class
默认情况下,paramters是从`ActiveSupport::HashWithIndifferentAccess`得到的,这当然是可以改变的

```ruby
class API < Grape::API
  include Grape::Extensions::Hashie::Mash::ParamBuilder

  params do
    optional :color, type: String
  end
  get do
    params.color # instead of params[:color]
  end
```
也可以用build_with在个别parameter上覆盖
```ruby
params do
  build_with Grape::Extensions::Hash::ParamBuilder
  optional :color, type: String
end
```
在上面的例子中`parmas["color"]`将返回`nil`因为params是一个hash

可用的parameter builders 有`Grape::Extensions::Hash::ParamBuilder`, `Grape::Extensions::ActiveSupport::HashWithIndifferentAccess::ParamBuilder`和`Grape::Extensions::Hashie::Mash::ParamBuilder`

##### Declared
grape允许你只访问经过params块声明过的参数,它过滤了那些已经通过但是不被允许的参数,看下面的例子
```ruby
format :json

post 'users/signup' do
  { 'declared_params' => declared(params) }
end
```
如果你没有指定任何参数,`declared`回返回一个空的hash
##### 请求
```ruby
curl -X POST -H "Content-Type: application/json" localhost:9292/users/signup -d '{"user": {"first_name":"first name", "last_name": "last name"}}'
```
##### 响应
```ruby
{
  "declared_params": {}
}
```
当添加参数requirements,grape就会返回声明过的参数
```ruby
format :json

params do
  requires :user, type: Hash do
    requires :first_name, type: String
    requires :last_name, type: String
  end
end

post 'users/signup' do
  { 'declared_params' => declared(params) }
end
```
如上同样的请求,会返回
```ruby
{
  "declared_params": {
    "user": {
      "first_name": "first name",
      "last_name": "last name"
    }
  }
}
```
这个返回的hash是`ActiveSupport::HashWithIndifferentAccess`的实例
这类`declared`方法是不允许在`before`过滤器中,因为它们是在参数转换前工作的
##### 添加父命名空间
默认情况下,`declared(params)`包含在所有父命名空间定义的函数,如果你想只返回当前命名空间的参数,你可以将`include_parent_namespaces`选项设为`false`
```ruby
include_parent_namespaces option to false.

format :json

namespace :parent do
  params do
    requires :parent_name, type: String
  end

  namespace ':parent_name' do
    params do
      requires :child_name, type: String
    end
    get ':child_name' do
      {
        'without_parent_namespaces' => declared(params, include_parent_namespaces: false),
        'with_parent_namespaces' => declared(params, include_parent_namespaces: true),
      }
    end
  end
end
```
##### 请求
```ruby
curl -X GET -H "Content-Type: application/json" localhost:9292/parent/foo/bar
```

##### 响应
```ruby
{
  "without_parent_namespaces": {
    "child_name": "bar"
  },
  "with_parent_namespaces": {
    "parent_name": "foo",
    "child_name": "bar"
  },
}
```
##### 包含missing
默认情况下 `declared(params)`包含值为`nil`的参数,如果你想只返回不为空的参数,你可以使用`include_missing`选项,默认情况下`include_missing`设为`true`
```ruby
format :json

params do
  requires :first_name, type: String
  optional :last_name, type: String
end

post 'users/signup' do
  { 'declared_params' => declared(params, include_missing: false) }
end
```
##### 请求
```ruby
curl -X POST -H "Content-Type: application/json" localhost:9292/users/signup -d '{"user": {"first_name":"first name", "random": "never shown"}}'
```
##### 响应 include_missing: false
```ruby
{
  "declared_params": {
    "user": {
      "first_name": "first name"
    }
  }
}
```
##### 响应 include_missing:true
```ruby
{
  "declared_params": {
    "first_name": "first name",
    "last_name": null
  }
}
```
它同样适用于嵌套hash
```ruby
format :json

params do
  requires :user, type: Hash do
    requires :first_name, type: String
    optional :last_name, type: String
    requires :address, type: Hash do
      requires :city, type: String
      optional :region, type: String
    end
  end
end

post 'users/signup' do
  { 'declared_params' => declared(params, include_missing: false) }
end
```
##### 请求
```ruby
curl -X POST -H "Content-Type: application/json" localhost:9292/users/signup -d '{"user": {"first_name":"first name", "random": "never shown", "address": { "city": "SF"}}}'
```
##### 响应 include_missing:false
```ruby
{
  "declared_params": {
    "user": {
      "first_name": "first name",
      "address": {
        "city": "SF"
      }
    }
  }
}
```
##### 响应 include_missing:true
```ruby
{
  "declared_params": {
    "user": {
      "first_name": "first name",
      "last_name": null,
      "address": {
        "city": "Zurich",
        "region": null
      }
    }
  }
}
```
注意！当值为nil的时候,就算是`include_missing`设置为`false`也会返回nil

##### <a name="1">参数验证和强制类型转换</a>
你可以定义验证和类型选项,在参数的`params`块中

```ruby
params do
  requires :id, type: Integer
  optional :text, type: String, regexp: /\A[a-z]+\z/
  group :media, type: Hash do
    requires :url
  end
  optional :audio, type: Hash do
    requires :format, type: Symbol, values: [:mp3, :wav, :aac, :ogg], default: :mp3
  end
  mutually_exclusive :media, :audio
end
put ':id' do
  # params[:id] is an Integer
end
```
在定义了类型之后,在验证之后进行隐式转换,保证输出的类型符合
可以设定一个默认值
```ruby
params do
  optional :color, type: String, default: 'blue'
  optional :random_number, type: Integer, default: -> { Random.rand(1..100) }
  optional :non_random_number, type: Integer, default:  Random.rand(1..100)
end
```

默认值是及早求值的,像上面例子中`:num_rondon_number`会每次返回相同的值,要想惰性求值需要使用`lambda`，像`:random_number`一样
注意设定的默认值,也需要通过验证,下面例子中会总是失败，如果`:color`没有明确规定

```ruby
params do
  optional :color, type: String, default: 'blue', values: ['red', 'green']
end
```
正确的方式是保证默认值值通过所有的验证
```ruby
params do
  optional :color, type: String, default: 'blue', values: ['blue', 'red', 'green']
end
```
被支持的参数类型
以下是被grape直接支持的类型
- Integer
- Float
- Bigdecimal
- Numeric
- Date
- DateTime
- Time
- Boolean
- String
- Symbol
- Rack::Multipart::UploadedFile (alias File)
- JSON
##### Integer/Fixnum 和强制转换
请注意ruby 2.4 版本之后，数字被转换成`Integer`类型,而2.4版本之前,它被转换成`Fixnum`
```ruby
params do
  requires :integers, type: Hash do
    requires :int, coerce: Integer
  end
end
get '/int' do
  params[:integers][:int].class
end

...

get '/int' integers: { int: '45' }
  #=> Integer in ruby 2.4
  #=> Fixnum in earlier ruby version
```
##### 自定义类型和转换
除了上面列出的默认支持的类型之外,只要提供强制转换任何类都能作为类型,如果类型提供了`parse`类方法,grape就会自动使用它.这个方法带入一个字符串参数并返回一个正确类型的实例,或者引发异常表明该值无效
例如
```ruby
class Color
  attr_reader :value
  def initialize(color)
    @value = color
  end

  def self.parse(value)
    fail 'Invalid color' unless %w(blue red green).include?(value)
    new(value)
  end
end

params do
  requires :color, type: Color, default: Color.new('blue')
  requires :more_colors, type: Array[Color] # Collections work
  optional :unique_colors, type: Set[Color] # Duplicates discarded
end

get '/stuff' do
  # params[:color] is already a Color.
  params[:color].value
end
```
或者可以使用`coerce_with`方法为任何参数提供强制转换方法.可以按照优先顺序,给出拥有`parse`或`call`类方法的类或者对象,这个方法必须接受一个字符串并返回一符合该它的值
```ruby
params do
  requires :passwd, type: String, coerce_with: Base64.method(:decode)
  requires :loud_color, type: Color, coerce_with: ->(c) { Color.parse(c.downcase) }

  requires :obj, type: Hash, coerce_with: JSON do
    requires :words, type: Array[String], coerce_with: ->(val) { val.split(/\s+/) }
    optional :time, type: Time, coerce_with: Chronic
  end
end
```
例如将`correce_with`配合`lambda`使用(当然如果有`parse`类方法也可以使用)它就会解析字符串然后返回一个数字形式的数组,来匹配`Array[Integer]`类型
```ruby
params do
  requires :values, type: Array[Integer], coerce_with: ->(val) { val.split(/\s+/).map(&:to_i) }
end
```
Grape 会强制匹配类型,如果不符合会拒绝访问,可以重写该行为,自定义该行为需要`parsed?`类方法，返回`true`表明值通过类型验证
```ruby
class SecureUri
  def self.parse(value)
    URI.parse value
  end

  def self.parsed?(value)
    value.is_a? URI::HTTPS
  end
end

params do
  requires :secure_uri, type: SecureUri
end
```

##### Multipart File类型参数
grape 使用`Rack::Request`构建对multipart file参数的支持,这个参数可以通过`type:File`声明
```ruby
params do
  requires :avatar, type: File
end
post '/' do
  params[:avatar][:filename] # => 'avatar.png'
  params[:avatar][:type] # => 'image/png'
  params[:avatar][:tempfile] # => #<File>
end
```
##### 一流的 `json` 类型
Grape支持使用`type:JSON`声明支持参数给出复杂的json格式字符串,在任何情况下JSON对象和数组都可以被平等接受,无论哪种情况都验证嵌套的验证规则
```ruby
params do
  requires :json, type: JSON do
    requires :int, type: Integer, values: [1, 2, 3]
  end
end
get '/' do
  params[:json].inspect
end

client.get('/', json: '{"int":1}') # => "{:int=>1}"
client.get('/', json: '[{"int":"1"}]') # => "[{:int=>1}]"

client.get('/', json: '{"int":4}') # => HTTP 400
client.get('/', json: '[{"int":4}]') # => HTTP 400
```
另外`type:Array[JSON]`可以被使用,它会标记参数为数组对象,如果一个单独的对象也会被包装成数组
```ruby
params do
  requires :json, type: Array[JSON] do
    requires :int, type: Integer
  end
end
get '/' do
  params[:json].each { |obj| ... } # always works
end
```
更加严格的控制可能提供的json结构类型,可以使用`type:Array, coerce_with: JSON`或者`type: Hash, coerce_with: JSON`

##### 多种允许的类型
变体数据类型的参数可以用`types`选项来声明而不是`type`选项来声明
```ruby
params do
  requires :status_code, types: [Integer, String, Array[Integer, String]]
end
get '/' do
  params[:status_code].inspect
end

client.get('/', status_code: 'OK_GOOD') # => "OK_GOOD"
client.get('/', status_code: 300) # => 300
client.get('/', status_code: %w(404 NOT FOUND)) # => [404, "NOT", "FOUND"]
```
在特殊的情况下,变体数据类型的成员同样也可以被声明,通过传递多个成员的`Set`或`Array`给`type:`
```ruby
params do
  requires :status_codes, type: Array[Integer,String]
end
get '/' do
  params[:status_codes].inspect
end

client.get('/', status_codes: %w(1 two)) # => [1, "two"]
```
##### 嵌套参数的验证
参数可以被嵌套通过`group`或调用`requires`或者`optional`块,在<a href="#1">上面的例子中</a>,这意味着`params[:media][:url]`只有在`params[:id]`是存在时才存在,同理`params[:audio][:format]`和`params[:audio]`也是一样.使用块`group`,`requires`和`optional`可以接收一个额外的`type`属性这是`Array`或者是`Hash`,并且它的默认值是`Array`.根据这个值,散列参数将被视为hash或者是数组中的hash
```ruby
params do
  optional :preferences, type: Array do
    requires :key
    requires :value
  end

  requires :name, type: Hash do
    requires :first_name
    requires :last_name
  end
end
```
##### 关联参数
假设一些参数只有在一些参数存在的情况才有意义;Grape允许你通过在参数块中`given`方法表明这种关系。例如
```ruby
params do
  optional :shelf_id, type: Integer
  given :shelf_id do
    requires :bin_id, type: Integer
  end
end
```
在上面的例子中grape会使用`blank?`方法去检测`shelf_id`参数是否存在

`given`同样可以通过`Proc`自定义,在下面例子中`description`只有在`category`的值为`foo`的时候才有效
```ruby
params do
  optional :category
  given category: ->(val) { val == 'foo' } do
    requires :description
  end
```
##### 分组选项
参数选项可以分组,如果你想为多个参数设置常见的验证这将会很有用,下面的例子中展示了一典型的情况及参数共享通用的选项
```ruby
params do
  requires :first_name, type: String, regexp: /w+/, desc: 'First name'
  requires :middle_name, type: String, regexp: /w+/, desc: 'Middle name'
  requires :last_name, type: String, regexp: /w+/, desc: 'Last name'
end
```
Grape允许你通过在参数块中的`with`方法实现相同的逻辑,就像
```ruby
params do
  with(type: String, regexp: /w+/) do
    requires :first_name, desc: 'First name'
    requires :middle_name, desc: 'Middle name'
    requires :last_name, desc: 'Last name'
  end
end
```
##### 别名
你可以通过`as`来设置参数的别名,这在重构api时会非常有用
```ruby
resource :users do
  params do
    requires :email_address, as: :email
    requires :password
  end
  post do
    User.create!(declared(params)) # User takes email and password
  end
end
```
传递给`as`的值是调用`params`或`declared(params)`的关键

##### 内置验证器
##### `allow_blank`
参数可以通过`allow_blank`来确保它们都有一个值,默认情况下,`requires`只是验证请求中是否发送的该参数,并不管它的值是多少.当`allow_blank:false`的情况下,空的值和空白的值都会被视为无效.
`allow_blank`可以作用于`requires`和`optional`.如果参数是required,它必须包含一个值.如果是optional,它可能没有在请求中发送但是如果它一旦被发送,它必须包含一个有效的值,而不能是空字符串,或者为空
```ruby
params do
  requires :username, allow_blank: false
  optional :first_name, allow_blank: false
end
```
###### `values`
参数可以通过`values`选项设定为特定的值
```ruby
params do
  requires :status, type: Symbol, values: [:not_started, :processing, :done]
  optional :numbers, type: Array[Integer], default: 1, values: [1, 2, 3, 5, 8]
end
```
提供一个范围给`values`选项,可以确保参数在指定范围内(使用`Range#include?`)
```ruby
params do
  requires :latitude, type: Float, values: -90.0..+90.0
  requires :longitude, type: Float, values: -180.0..+180.0
  optional :letters, type: Array[String], values: 'a'..'z'
end
```
注意范围的2个端点都必须是与你的`:type`选项的类型一致(如果没有设定`type`选项,那么`type`会被认定为范围的第一个端点的类),所以下面的情况都是无效的
```ruby
params do
  requires :invalid1, type: Float, values: 0..10 # 0.kind_of?(Float) => false
  optional :invalid2, values: 0..10.0 # 10.0.kind_of?(0.class) => false
end
```
同样的`:values`选项也可以通过`Proc`方式提供,以懒惰的方式应对每次请求,如果`Proc`的arity为0(即它不需要参数),它会返回一个范围或者列表来验证参数
例如,给出一个模型状态,你或许想通过`HashTag`模型中的tag进行限制
```ruby
params do
  requires :hashtag, type: String, values: -> { Hashtag.all.map(&:tag) }
end
```
或者用一个Proc来验证每个参数的值,在这种情况下,如果参数有效就会返回真,如果返回假,则视为参数无效
```ruby
params do
  requires :number, type: Integer, values: ->(v) { v.even? && v < 25 }
end
```
Proc适用于单个情况,如果这个验证多次出现可以考虑使用<a href="#2">自定义验证</a>

##### `except_values`
也可以通过`except_values`选项,来限制参数
它也可以接收`Array`,`Range`或者是`Proc`,但是它与`values`正好相反
```ruby
params do
  requires :browser, except_values: [ 'ie6', 'ie7', 'ie8' ]
  requires :port, except_values: { value: 0..1024, message: 'is not allowed' }
  requires :hashtag, except_values: -> { Hashtag.FORBIDDEN_LIST }
end
```
##### `regexp`
`regexp`选项可以通过正则匹配的方式过滤参数,当参数不能正则匹配时,会返回一个错误,对于`reuires`和`optional`参数都是如此
```ruby
params do
  requires :email, regexp: /.+@.+/
end
```
如果参数为空的时候该验证器会跳过,所有如果要预防这种情况要使用`allow_blank:false`
```ruby
params do
  requires :email, allow_blank: false, regexp: /.+@.+/
end
```
`mutually_exclusive`
多个参数可以使用`mutually_exclusive`选项,确保他们不会在同一个请求中出现
```ruby
params do
  optional :beer
  optional :wine
  mutually_exclusive :beer, :wine
end
```
可以定义多个
```ruby
params do
  optional :beer
  optional :wine
  mutually_exclusive :beer, :wine
  optional :scotch
  optional :aquavit
  mutually_exclusive :scotch, :aquavit
end
```
警告:不要对任何必须的参数定义互斥集合,2个互斥的必须参数,会造成请求永远无法通过验证,使得端口失去作用,一个必须的参数和一个非必须的参数组成互斥,会使后者永远无法通过验证

注意`defalut`和`mutually_exclusive`一起使用时,会导致多个参数始终有个默认值,而引发`Grape::Exceptions::Validation`异常

##### `exactly_one_of`
多个参数可以使用`exactly_one_of`,确保只有一个参数被选择
```ruby
params do
  optional :beer
  optional :wine
  exactly_one_of :beer, :wine
end
```
##### `at_least_one_of`
多个参数可以使用`at_least_one_of`,确保最少有一个参数被选择
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  at_least_one_of :beer, :wine, :juice
end
```

##### `all_of_none_of`
多个参数可以使用`all_of_none_of`,确保全部都被选择或者都不被选择
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  all_or_none_of :beer, :wine, :juice
end
```
##### 嵌套 `mutually_exclusive`, `exactly_one_of`, `at_least_one_of`, `all_or_none_of`
所有这些方法都可以用在任何嵌套层
```ruby
params do
  requires :food, type: Hash do
    optional :meat
    optional :fish
    optional :rice
    at_least_one_of :meat, :fish, :rice
  end
  group :drink, type: Hash do
    optional :beer
    optional :wine
    optional :juice
    exactly_one_of :beer, :wine, :juice
  end
  optional :dessert, type: Hash do
    optional :cake
    optional :icecream
    mutually_exclusive :cake, :icecream
  end
  optional :recipe, type: Hash do
    optional :oil
    optional :meat
    all_or_none_of :oil, :meat
  end
end
```
##### 为验证和类型转换添加命名空间
命名空间允许定义参数,并运行命名空间下的任何方法
```ruby
namespace :statuses do
  params do
    requires :user_id, type: Integer, desc: 'A user ID.'
  end
  namespace ':user_id' do
    desc "Retrieve a user's status."
    params do
      requires :status_id, type: Integer, desc: 'A status ID.'
    end
    get ':status_id' do
      User.find(params[:user_id]).statuses.find(params[:status_id])
    end
  end
end
```
