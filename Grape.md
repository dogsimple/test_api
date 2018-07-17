### 注意
如有疑问请参阅<a href="https://github.com/ruby-grape/grape">Grape</a>官方文档
### 安装
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
`namespace`方法拥有许多别名,包括`group`,`resource`,`rsources`和`segment`.可以在你的api中使用最合适
你也可以方便的使用`route_param`将你的路由参数设置成命名空间

```ruby
namespace :statuses do
  route_param :id do
    desc 'Returns all replies for a status.'
    get 'replies' do
      Status.find(params[:id]).replies
    end
    desc 'Returns a status.'
    get do
      Status.find(params[:id])
    end
  end
end
```
你还可以通过'route_param'的选项来定义参数的类型
```ruby
namespace :arithmetic do
  route_param :n, type: Integer do
    desc 'Returns in power'
    get 'power' do
      params[:n] ** params[:n]
    end
  end
end
```
自定义验证器
```ruby
class AlphaNumeric < Grape::Validations::Base
  def validate_param!(attr_name, params)
    unless params[attr_name] =~ /\A[[:alnum:]]+\z/
      fail Grape::Exceptions::Validation, params: [@scope.full_name(attr_name)], message: 'must consist of alpha-numeric characters'
    end
  end
end
```
```ruby
params do
  requires :text, alpha_numeric: true
end
```
你也可以创建带参数的自定义类
```ruby
class Length < Grape::Validations::Base
  def validate_param!(attr_name, params)
    unless params[attr_name].length <= @option
      fail Grape::Exceptions::Validation, params: [@scope.full_name(attr_name)], message: "must be at the most #{@option} characters long"
    end
  end
end
```
```ruby
params do
  requires :text, length: 140
end
```
你也可以创建自定义验证,使用请求去验证参数,比如你想一些参数只给管理员提供,你可以这样做
```ruby
class Admin < Grape::Validations::Base
  def validate(request)
    # return 如果请求中没有这个参数
    # @attrs 是我们当前验证的列表
    # 在我们的示例中这个方法将被调用一次
    # @attrs一次是[:admin_field]一次是[:admin_false_field]
    return unless request.params.key?(@attrs.first)
    # 检查admin表示是否设置为true
    return unless @option
    # 检查user是否是admin
    # 作为示例通过从请求传递token来检查是不是admin
    fail Grape::Exceptions::Validation, params: @attrs, message: 'Can not set admin-only field.' unless request.headers['X-Access-Token'] == 'admin'
  end
end
```
然后在端口使用它
```ruby
params do
  optional :admin_field, type: String, admin: true
  optional :non_admin_field, type: String
  optional :admin_false_field, type: String, admin: false
end
```
每个验证器都有自己的实例,中意味着每个验证器都有自己的状态
##### 验证错误
收集验证和强制错误,并引发`Grape::Exeptions::ValidationErrors`类型的异常,如果异常未被捕获,它将以状态400和错误消息进行响应,验证错误按参数名称分组,可以通过`Grape::Execptions::ValidationErrors#error`访问

一个默认的从一个`Grape::Execptions::ValidationErrors#error`而来的响应是一个可读的字符串,例如'beer, wine are mutually exclusive',在下面的例子中
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  exactly_one_of :beer, :wine, :juice
end
```
你可以rescue一个`Grape::Execptions::ValidationErrors`并使用自定义响应进行响应,或者将响应转换成格式正确的JSON,以获取用于分割各个参数的和相应错误消息的JSON API,下面用`rescue_from`示例生成`[{"params": ["beer", "wine"], "messages": ["are mutually exclusive"]}]`.
```ruby
format :json
subject.rescue_from Grape::Exceptions::ValidationErrors do |e|
  error! e, 400
end
```
`Grape::Exceptions::ValidationErrors#full_messages`返回一个数组作为验证信息
`Grape::Exceptions::ValidationErrors#messages`将消息变成一个字符串

要使用一组验证消息进行响应,你可以使用`Grape::Exceptions::ValidationErrors#full_messages`
```ruby
format :json
subject.rescue_from Grape::Exceptions::ValidationErrors do |e|
  error!({ messages: e.full_messages }, 400)
end
```
Grape 默认返回所有的验证和强制错误.要在特定参数无效时跳过所有后续验证,请使用`fail_fast: true`
以下示例不会检查`:wine`是否存在,除非它找到`:beer`
```ruby
params do
  required :beer, fail_fast: true
  required :wine
end
```
空参数的的请求会返回一个单独的`Grape::Exceptions::ValidationErrors`错误
同样下面的例子中`:blah`为空同样不会触发正则表达式验证
```ruby
params do
  required :blah, allow_blank: false, regexp: /blah/, fail_fast: true
end
```
##### l18n
Grape 支持l18n以获取与参数相关的错误信息,但是如果未提供默认语言环境的翻译,则会回退到英语
##### 自定义验证提示
Grape 提供参数相关和强制相关的自定义错误验证提示
`presence`, `allow_blank`, `values`, `regexp`
```ruby
params do
  requires :name, values: { value: 1..10, message: 'not in range from 1 to 10' }, allow_blank: { value: false, message: 'cannot be blank' }, regexp: { value: /^[a-z]+$/, message: 'format is invalid' }, message: 'is required'
end
```
`all_or_none_of`
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  all_or_none_of :beer, :wine, :juice, message: "all params are required or none is required"
end
```
`mutually_exclusive`
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  mutually_exclusive :beer, :wine, :juice, message: "are mutually exclusive cannot pass both params"
end
```
`exactly_one_of`
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  exactly_one_of :beer, :wine, :juice, message: {exactly_one: "are missing, exactly one parameter is required", mutual_exclusion: "are mutually exclusive, exactly one parameter is required"}
end
```
`at_least_one_of`
```ruby
params do
  optional :beer
  optional :wine
  optional :juice
  at_least_one_of :beer, :wine, :juice, message: "are missing, please specify at least one param"
end
```
`Coerce`
```ruby
params do
  requires :int, type: {value: Integer, message: "type cast is invalid" }
end
```
`With Lambdas`
```ruby
params do
  requires :name, values: { value: -> { (1..10).to_a }, message: 'not in range from 1 to 10' }
end
```
`传递il8n翻译的符号`
你可以传递通过il8n翻译的符号给自定义的验证消息
```ruby
params do
  requires :name, message: :name_required
end
```
```ruby
# en.yml

en:
  grape:
    errors:
      format: ! '%{attributes} %{message}'
      messages:
        name_required: 'must be present'
```
##### 覆盖属性名称
```ruby
# en.yml

en:
  grape:
    errors:
      format: ! '%{attributes} %{message}'
      messages:
        name_required: 'must be present'
      attributes:
        name: 'Oops! Name'
```
会生成'Oop! Name must be present'

默认情况
无法为默认选项自定义消息选项,此时它会插入值`%{option}: %{value1}is incompatible with %{option}: %{value2}`.你可以通过修改en,yml文件中的`incompatible_option_values`消息键值来修改默认的提示信息.
```ruby
params do
  requires :name, values: { value: -> { (1..10).to_a }, message: 'not in range from 1 to 10' }, default: 5
end
```
##### Headers
请求的headers可以通过`headers`helper或者`env`获得
```ruby
get do
  error!('Unauthorized', 401) unless headers['Secret-Password'] == 'swordfish'
end
```
```ruby
get do
  error!('Unauthorized', 401) unless env['HTTP_SECRET_PASSWORD'] == 'swordfish'
end
```
你可以设置响应header通过API 中的`header`
```ruby
header 'X-Robots-Tag', 'noindex'

```
当抛出`error!`时,传递对应的headers参数
```ruby
error! 'Unauthorized', 401, 'X-Error-Detail' => 'Invalid token.'
```
##### Routes
可选的,你可以设置端口或者命名空间的正则匹配来定义你的要求.这个路由只会匹配符合要求的
```ruby
get ':id', requirements: { id: /[0-9]*/ } do
  Status.find(params[:id])
end

namespace :outer, requirements: { id: /[0-9]*/ } do
  get :id do
  end

  get ':id/edit' do
  end
end
```
##### Helpers
你可以定义helper方法,然后在你的端口使用`helper`宏通过块或者是数组的方式引入模块
```ruby
module StatusHelpers
  def user_info(user)
    "#{user} has statused #{user.statuses} status(s)"
  end
end

module HttpCodesHelpers
  def unauthorized
    401
  end
end

class API < Grape::API
  # define helpers with a block
  helpers do
    def current_user
      User.find(params[:user_id])
    end
  end

  # or mix in an array of modules
  helpers StatusHelpers, HttpCodesHelpers

  before do
    error!('Access Denied', unauthorized) unless current_user
  end

  get 'info' do
    # helpers available in your endpoint and filters
    user_info(current_user)
  end
end
```
你可以使用`helpers`定义可复用的`helpers`.
```ruby
class API < Grape::API
  helpers do
    params :pagination do
      optional :page, type: Integer
      optional :per_page, type: Integer
    end
  end

  desc 'Get collection'
  params do
    use :pagination # aliases: includes, use_scope
  end
  get do
    Collection.page(params[:page]).per(params[:per_page])
  end
end
```
你也可以使用helper方法定义可复用的`params`
```ruby
module SharedParams
  extend Grape::API::Helpers

  params :period do
    optional :start_date
    optional :end_date
  end

  params :pagination do
    optional :page, type: Integer
    optional :per_page, type: Integer
  end
end

class API < Grape::API
  helpers SharedParams

  desc 'Get collection.'
  params do
    use :period, :pagination
  end

  get do
    Collection
      .from(params[:start_date])
      .to(params[:end_date])
      .page(params[:page])
      .per(params[:per_page])
  end
end
```
Helpers支持使用块来帮助设置默认值,在下面的api中可以返回`id`或者`created_at`按照`desc`或者`asc`排列的集合
```ruby
module SharedParams
  extend Grape::API::Helpers

  params :order do |options|
    optional :order_by, type: Symbol, values: options[:order_by], default: options[:default_order_by]
    optional :order, type: Symbol, values: %i(asc desc), default: options[:default_order]
  end
end

class API < Grape::API
  helpers SharedParams

  desc 'Get a sorted collection.'
  params do
    use :order, order_by: %i(id created_at), default_order_by: :created_at, default_order: :asc
  end

  get do
    Collection.send(params[:order], params[:order_by])
  end
end
```
##### Path helpers
如果你需要在端口生成路径的方法,请查看`grape-route-helpers`gem
##### Parameter 文档
你可以通过`documentation`哈希将文档引入到`params`
```ruby
params do
  optional :first_name, type: String, documentation: { example: 'Jim' }
  requires :last_name, type: String, documentation: { example: 'Smith' }
end
```
##### Cookies
你可以通过set,get和delete非常简单的使用`cookies`方法
```ruby
class API < Grape::API
  get 'status_count' do
    cookies[:status_count] ||= 0
    cookies[:status_count] += 1
    { status_count: cookies[:status_count] }
  end

  delete 'status_count' do
    { status_count: cookies.delete(:status_count) }
  end
end
```
使用一个基本的hash结构类型设置更多的值
```ruby
cookies[:status_count] = {
  value: 0,
  expires: Time.tomorrow,
  domain: '.twitter.com',
  path: '/'
}

cookies[:status_count][:value] +=1
```
使用`delete`删除cookie
```ruby
cookies.delete :status_count
```
指定可选路径
```ruby
cookies.delete :status_count, path: '/'
```
##### HTTP Status Code
默认情况下post请求Grape返回201,不返回任何内容的delete请求返回204,其他请求则返回200,你可以使用`status`查询设置HTTP states值
```ruby
post do
  status 202

  if status == 200
     # do some thing
  end
end
```
你还可以使用Rack utils提供的status codes
```ruby
post do
  status :no_content
end
```
##### Redirecting
你可以临时(302)或者永久(301)跳向一个新网址
302
```ruby
redirect '/statuses'
```
301
```ruby
redirect '/statuses', permanent: true
```
##### 识别路径
你可以识别与给定路径相匹配的端口
这个api返回`Grape::Endpoint`的实例
```ruby
class API < Grape::API
  get '/statuses' do
  end
end

API.recognize_path '/statuses'
```
##### 被允许的方法
当你添加一个资源的`get`路由时,`HEAD`方法的路由也将被自动添加.你可以使用`do_not_route_head!`禁止这种行为
```ruby
class API < Grape::API
  do_not_route_head!

  get '/example' do
    # only responds to GET
  end
end
```
当你添加为资源添加一个路由,这个路由的`OPTIONS`方法也同样被添加.对OPTIONS请求的响应将包括列出支持方法的"Allow"header.如果这个资源拥有`before`和`after`回调它们将会执行,但是其他回调不会执行.
```ruby
class API < Grape::API
  get '/rt_count' do
    { rt_count: current_user.rt_count }
  end

  params do
    requires :value, type: Integer, desc: 'Value to add to the rt count.'
  end
  put '/rt_count' do
    current_user.rt_count += params[:value].to_i
    { rt_count: current_user.rt_count }
  end
end
```
```ruby
curl -v -X OPTIONS http://localhost:3000/rt_count

> OPTIONS /rt_count HTTP/1.1
>
< HTTP/1.1 204 No Content
< Allow: OPTIONS, GET, PUT
```
使用`do_not_route_options!`禁用这种行为.
如果请求一个不受支持的HTTP方法,将会返回HTTP 405(不支持的方法).如果资源有`before`回调它会被执行,但是其他回调不会被执行.
```ruby
curl -X DELETE -v http://localhost:3000/rt_count/

> DELETE /rt_count/ HTTP/1.1
> Host: localhost:3000
>
< HTTP/1.1 405 Method Not Allowed
< Allow: OPTIONS, GET, PUT
```
##### 抛出异常
你可以退出api方法通过`error!`抛出异常
```ruby
error! 'Access Denied', 401
```
任何可以响应`#to_s`的内容都可以作为`error!`的第一个参数
```ruby
error! :not_found, 404
```
你还可以在抛出异常时返回Json格式的对象,并传递哈希而不是message.
```ruby
error!({ error: 'unexpected error', detail: 'missing widget' }, 500)
```
你可以通过grape-entity gem 显示具体的错误.
```ruby
module API
  class Error < Grape::Entity
    expose :code
    expose :message
  end
end
```
下面的例子在`http_codes`定义中指定了实体
```ruby
desc 'My Route' do
  failure [[408, 'Unauthorized', API::Error]]
end
error!({message: 'Unauthorized'}, 408)
```
以下示例在错误消息中明确指定所呈现的实体.
```ruby
desc 'My Route' do
 failure [[408, 'Unauthorized']]
end
error!({ message: 'Unauthorized', with: API::Error }, 408)
```
##### 默认错误的HTTP状态码
默认情况下对于`error!`grape返回500状态码.你可以通过`default_error_status`改变它.
```ruby
class API < Grape::API
  default_error_status 400
  get '/example' do
    error! 'This should have http status code 400'
  end
end
```
##### 处理404
对于grape来说,处理api中的所有404,使用catch-all会很有用.在最简单的形式中,它可以像:
```ruby
route :any, '*path' do
  error! # or something else
end
```
在api的最末端定义此端口非常重要,因为实际上它接受每个请求.
##### 异常处理
grape可以捕获所有的`StandardError`异常并已api格式返回
```ruby
class Twitter::API < Grape::API
  rescue_from :all
end
```
这会模仿默认的`rescue`行为如果不知道异常的类型.任何其他异常都应该被捕获,见下文.
Grape 会捕获所有的异常,并使用内置的异常处理.这将提供与`rescue_from :all`相同的行为除了Grape将使用继承于Grape::Exceptions::Base的所有异常类的异常行为处理.
这种设置是为了提供一种简单的方式处理常见的异常并返回api格式的任何异常.
```ruby
class Twitter::API < Grape::API
  rescue_from :grape_exceptions
end
```
你可以捕获特定的异常
```ruby
class Twitter::API < Grape::API
  rescue_from ArgumentError, UserDefinedError
end
```
这种情况下`UserDefinedError`都必须继承于`StandardError`.
记住你可以将这2这情况结合起来(优先捕获自定义异常).例如,它对于处理除了Grape验证错误之外的所有异常非常有用.
```ruby
class Twitter::API < Grape::API
  rescue_from Grape::Exceptions::ValidationErrors do |e|
    error!(e, 400)
  end

  rescue_from :all
end
```
这个错误格式会匹配请求的格式,看下面的"Content-Types"
可以使用Proc定义常见的错误格式,以及额外的类型.
```ruby
class Twitter::API < Grape::API
  error_formatter :txt, ->(message, backtrace, options, env, original_exception) {
    "error: #{message} from #{backtrace}"
  }
end
```
你也可以使用模块和类
```ruby
module CustomFormatter
  def self.call(message, backtrace, options, env, original_exception)
    { message: message, backtrace: backtrace }
  end
end

class Twitter::API < Grape::API
  error_formatter :custom, CustomFormatter
end
```
你可以用代码块捕获所有的异常.`error!`会自动设置错误code和内容
```ruby
class Twitter::API < Grape::API
  rescue_from :all do |e|
    error!("rescued from #{e.class.name}")
  end
end
```
当然你也可以设置格式,状态码和headers
```ruby
class Twitter::API < Grape::API
  format :json
  rescue_from :all do |e|
    error!({ error: 'Server error.' }, 500, { 'Content-Type' => 'text/error' })
  end
end
```

你还可以通过块捕获所有异常然后在最底层的Rack response做出处理
```ruby
class Twitter::API < Grape::API
  rescue_from :all do |e|
    Rack::Response.new([ e.message ], 500, { 'Content-type' => 'text/error' }).finish
  end
end
```
捕获特殊的异常
```ruby
class Twitter::API < Grape::API
  rescue_from ArgumentError do |e|
    error!("ArgumentError: #{e.message}")
  end

  rescue_from NoMethodError do |e|
    error!("NoMethodError: #{e.message}")
  end
end
```
默认情况下,`rescue_from`会抛出列出的所有异常和它的子类.
假设你定义了以下异常类.
```ruby
module APIErrors
  class ParentError < StandardError; end
  class ChildError < ParentError; end
end
```
然后下面的例子中`rescue_from`将抛出`APIErrors::ParentError`和它的子类`APIError::ChildError`中的异常
```ruby
rescue_from APIErrors::ParentError do |e|
    error!({
      error: "#{e.class} error",
      message: e.message
    }, e.status)
end
```
如果仅仅要抛出本类的异常,可以设置`rescue_subclasses: false`.下面的代码中,仅仅会抛出`RuntimeError`的异常,不会抛出其子类异常.
```ruby
rescue_from RuntimeError, rescue_subclasses: false do |e|
    error!({
      status: e.status,
      message: e.message,
      errors: e.errors
    }, e.status)
end
```
Helpers中也可以使用`rescue_from`
```ruby
class Twitter::API < Grape::API
  format :json
  helpers do
    def server_error!
      error!({ error: 'Server error.' }, 500, { 'Content-Type' => 'text/error' })
    end
  end

  rescue_from :all do |e|
    server_error!
  end
end
```
`rescue_from`的块必须返回一个`Rack::Response`对象,调用`error!`或者重新抛出异常
`with`关键字可以为`rescue_form`的选项,它可以传递方法名或Proc对象.
```ruby
class Twitter::API < Grape::API
  format :json
  helpers do
    def server_error!
      error!({ error: 'Server error.' }, 500, { 'Content-Type' => 'text/error' })
    end
  end

  rescue_from :all,          with: :server_error!
  rescue_from ArgumentError, with: -> { Rack::Response.new('rescued with a method', 400) }
end
```
##### 捕获命名空间内的异常
你可以把`rescue_from`放在命名空间之内,然后它将优于顶层空间定义的那些优先起作用
```ruby
class Twitter::API < Grape::API
  rescue_from ArgumentError do |e|
    error!("outer")
  end

  namespace :statuses do
    rescue_from ArgumentError do |e|
      error!("inner")
    end
    get do
      raise ArgumentError.new
    end
  end
end
```
在这里`inner`就是处理`ArgumentError`的结果

##### 无法捕获的异常情况
`Grape::Exceptions::InvalidVersionHeader`,会被抛出当请求header的版本与端口的当前版本不一致时,它无法通过`rescue_from` 块(即使是rescue_from :all)的形式被捕获.这是因为Grape依赖rack来捕获异常对于,对于存在不同版本相同端口的情况会尝试下一个版本的端口.
##### 应明确捕获的异常情况
任何不是`StandardError`子类的异常都应该被捕获.通常这种情况不是逻辑错误而是ruby的运行时错误.
##### Rails 3.x
当装载在容器中时,如rails 3.x ,rails 处理程序可能会处理呈现诸如"404 not found" 和"406 Not Acceptable"之类的错误.例如访问一个不存在的路由"/api/foo"抛出一个404,这个rails会转换成一个`ActionController::RoutingError`,可能会渲染一个html的错误页面
很多api都会喜欢阻止下游程序处理异常,你可以对于整个API或者单独的版本定义上设置`:cascade`选项为`false`,这将会从api响应中删除`X-Cascade: true`标头
```ruby
cascade false
```
```ruby
version 'v1', using: :header, vendor: 'twitter', cascade: false
```
##### 日志
`Grape::API`提供了一个`logger`方法,默认情况下它将从ruby标准库返回一个`logger`类的实例.
从一个端口记录信息,你需要一个helper方法使其在端口上下文中可以使用.
```ruby
class API < Grape::API
  helpers do
    def logger
      API.logger
    end
  end
  post '/statuses' do
    logger.info "#{current_user} has statused"
  end
end
```
更改logger级别
```ruby
class API < Grape::API
  self.logger.level = Logger::INFO
end
```
你也可以定义自己的记录器
```ruby
class MyLogger
  def warning(message)
    puts "this is a warning: #{message}"
  end
end

class API < Grape::API
  logger MyLogger.new
  helpers do
    def logger
      API.logger
    end
  end
  get '/statuses' do
    logger.warning "#{current_user} has statused"
  end
end
```
##### API 格式
你的api可以使用`content_type`声明支持格式.如你没有指定,Grape会支持XML,JSON,BINARY和TXT格式.默认的格式是`:txt`;你可以通过`default_format`改变它.基本上下面2个api是等效的
```ruby
class Twitter::API < Grape::API
  # no content_type declarations, so Grape uses the defaults
end

class Twitter::API < Grape::API
  # the following declarations are equivalent to the defaults

  content_type :xml, 'application/xml'
  content_type :json, 'application/json'
  content_type :binary, 'application/octet-stream'
  content_type :txt, 'text/plain'

  default_format :txt
end
```
如果你声明了任何`content_type`,Grape的默认设置都会被覆盖,比如,下面的api只会支持`:xml`和`:rss`格式,而不是`:txt`,`:json`或者`:binary`.重点是`:txt`格式没有被支持,所以需要设定新的`default_format`
```ruby
class Twitter::API < Grape::API
  content_type :xml, 'application/xml'
  content_type :rss, 'application/xml+rss'

  default_format :xml
end
```
序列化将自动进行,比如,不不必在每个JSON API端口调用`to_json`方法.响应格式按已下顺序进行.
- 如果指定了文件拓展名.如果文件是.json,选择JSON格式
- 如果指定了格式参数,使用查询字符串中format参数值.
- 如果指定了format格式,使用format选择设置的格式.
- 尝试从Accept标头中找到可接受的格式.
- 使用默认格式,如果定义了`default_format`选项
- 默认使用`:txt`.

例如,参考下面api
```ruby
class MultipleFormatAPI < Grape::API
  content_type :xml, 'application/xml'
  content_type :json, 'application/json'

  default_format :json

  get :hello do
    { hello: 'world' }
  end
end
```
- `GET/hello`(header: `Accept: */*`),没有拓展名或`format`参数因此会响应JSON格式(默认值).
- `GET/hello.xml`响应xml
- `GET /hello?format=xml`响应xml
- `GET /hello.xml?format=json`响应xml
- `GET /hello.xls`(header: `Accept: */*`)由于不支持xls,响应默认格式JSON
- `GET /hello.xls` `Accept: application/xml`响应xml
- `GET /hello.xls` `Accept: text/plain`响应JSON
你可以通过在API本身中指定env['api.format']来显式覆盖此过程.例如,以下api允许你上传任意文件并将其内容作为具有正确MIME类型的附件返回.
```ruby
class Twitter::API < Grape::API
  post 'attachment' do
    filename = params[:file][:filename]
    content_type MIME::Types.type_for(filename)[0].to_s
    env['api.format'] = :binary # there's no formatter for :binary, data will be returned "as is"
    header 'Content-Disposition', "attachment; filename*=UTF-8''#{CGI.escape(filename)}"
    params[:file][:tempfile].read
  end
end
```
你可以使用`format`让你的api中响应一个格式.如果你使用它,api不会响应`format`指定格式以外的文件名.例如,看下面API.
```ruby
class SingleFormatAPI < Grape::API
  format :json

  get :hello do
    { hello: 'world' }
  end
end
```
- `GET /hello`响应JSON.
- `GET /hello.json`响应JSON
- `GET /hello.xml`, `GET /hello.foobar`,响应404
- `GET /hello?format=xml` 响应406,因为xml不被支持
- `GET /hello` `Accept: application/xml`响应JSON

这些格式也用于解析,下面API仅响应JSON格式类型,并且不会解析除`application/json`,`application/x-www-form-urlencoded`,`multipart/form-data`,`multipart/related`和`multipart/mixed`之外的任何其他输入.其他任何请求都会返回HTTP 406 错误.
```ruby
class Twitter::API < Grape::API
  format :json
end
```
省略content-type时,除非指定了`default_format`,否则Grape将返回406错误.下面的例子中API会尝试使用JSON解析器解析没有内容类型的任何数据.
```ruby
class Twitter::API < Grape::API
  format :json
  default_format :json
end
```
如果你将`format`和`rescue_from: all`一起使用,错误也是返回相同的格式.如果你想这么做,使用`default_error_format`设置默认的错误格式.
```ruby
class Twitter::API < Grape::API
  format :json
  content_type :txt, 'text/plain'
  default_error_formatter :txt
end
```
可以使用Proc自定义当前格式或者其他格式.
```ruby
class Twitter::API < Grape::API
  content_type :xls, 'application/vnd.ms-excel'
  formatter :xls, ->(object, env) { object.to_xls }
end
```
你也可以使用模块和类实现它
```ruby
module XlsFormatter
  def self.call(object, env)
    object.to_xls
  end
end

class Twitter::API < Grape::API
  content_type :xls, 'application/vnd.ms-excel'
  formatter :xls, XlsFormatter
end
```
内置的格式化工具如下
- `:json`在可用时调用对象的`to_json`方法,否则调用`MultiJson.dump`
- `:xml`可用时候对象的`to_xml`方法一般是通过`MultiXMl`,负责调用`to_s`
- `:txt`可用的时候调用对象的`to_txt`方法,否则`to_s`
- `:serializable_hash`可用的时候调用对象的`serializable_hash`方法,否则倒退回`:json`
- `:binary`数据将按原样返回.

如果api收到的请求中存在body,并且Content-Type标头值为不受支持的类型,则Grape将返回"415 Unsupported Media Type"错误代码.

##### JSONP
Grape通过`Rack::JSONP`支持JSONP,它是rack-contrib gem的一部分,将rack-contrib添加到你的Gemfile中.
```ruby
require 'rack/contrib'

class API < Grape::API
  use Rack::JSONP
  format :json
  get '/' do
    'Hello World'
  end
end
```
##### CORS
Grape通过`Rack::CORS`支持CORS,rack-cors gem的一部分.添加`rack-cors`到你的`Gemfile`中,然后在你的config.ru文件中使用这个中间件.
```ruby
require 'rack/cors'

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: :get
  end
end

run Twitter::API
```
##### Content-type
Content-type是通过格式化工具设置的,你可以通过设置`Content-Type`标头在运行时覆盖响应的content-type
```ruby
class API < Grape::API
  get '/home_timeline_js' do
    content_type 'application/javascript'
    "var statuses = ...;"
  end
end
```
##### API 数据格式
Grape接受并解析使用POST和PUT方法发送的输入数据,如上面的所述.它还支持自定义的数据格式.你必须通过content_type声明其他内容类型,并可选择通过`parser`提供解析,除非Grape中已经有了一个解析器可用于自定义的格式.这样一个解析器可以是类或者是函数.
使用解析器,解析的数据可以在`env['api.request.body']`原样读取.没有解析器,数据也可以在`env['api.request.input']`中原样读取.
以下是一个简单的解析器,它将任何带有"text/custom"内容的输入类型分配给`:value`.该参数通过API调用中的`params[:value]`提供.
```ruby
module CustomParser
  def self.call(object, env)
    { value: object.to_s }
  end
end
```
```ruby
content_type :txt, 'text/plain'
content_type :custom, 'text/custom'
parser :custom, CustomParser

put 'value' do
  params[:value]
end
```
你可以按如下方式调用上述API
```ruby
curl -X PUT -d 'data' 'http://localhost:9292/value' -H Content-Type:text/custom -v
```
你可以设置content-type的值为nil来禁用解析.例如,对于解析器`:json`nil将完全禁用JSON解析.然后,请求的数据将在`env['api.request.body']`中按原样返回.
##### JSON和XML处理器
Grape使用`JSON`和`ActiveSupport::XmlMini`为JSON何XML的默认处理器.它还检测并支持multi_json和multi_xml.将这些gems添加到你的gemfile文件并将它们启用并允许你交换JSON和XML处理逻辑.
##### RESTful模型呈现
Grape支持一系列方法来呈现你的数据,并提供通用`present`方法,它接收俩个参数:要呈现的对象和与之关联的选项.选项通过`:with`传递,它定义了哪些实体需要暴露.
##### Grape Entities
添加grape-entity gem到你的gemfile文件,更多的细节请参阅它的官方文档
以下示例暴露了statues
```ruby
module API
  module Entities
    class Status < Grape::Entity
      expose :user_name
      expose :text, documentation: { type: 'string', desc: 'Status update text.' }
      expose :ip, if: { type: :full }
      expose :user_type, :user_id, if: ->(status, options) { status.user.public? }
      expose :digest do |status, options|
        Digest::MD5.hexdigest(status.txt)
      end
      expose :replies, using: API::Status, as: :replies
    end
  end

  class Statuses < Grape::API
    version 'v1'

    desc 'Statuses index' do
      params: API::Entities::Status.documentation
    end
    get '/statuses' do
      statuses = Status.all
      type = current_user.admin? ? :full : :default
      present statuses, with: API::Entities::Status, type: type
    end
  end
end
```
你可以使用以下代码直接在params块中使用实体文档`entity.documentation`.
```ruby
module API
  class Statuses < Grape::API
    version 'v1'

    desc 'Create a status'
    params do
      requires :all, except: [:ip], using: API::Entities::Status.documentation.except(:id)
    end
    post '/status' do
      Status.create! params
    end
  end
end
```
你可以使用可选的Symbol参数显示多个实体
```ruby
get '/statuses' do
    statuses = Status.all.page(1).per(20)
    present :total_page, 10
    present :per_page, 20
    present :statuses, statuses, with: API::Entities::Status
  end
```
这个响应会是
```ruby
{
    total_page: 10,
    per_page: 20,
    statuses: []
  }
```
除了单独组织实体之外,将它们作为命名空间类放在它们作为命名空间类放在它们所代表的模型下面可能很有用.
```ruby
class Status
  def entity
    Entity.new(self)
  end

  class Entity < Grape::Entity
    expose :text, :user_id
  end
end
```
如果你以这种方式组织实体,Grape将自动检测Entity类并使用它来呈现你的模型.在此示例中,如果你添加`present Status.new`到你的端口,Grape将自动检测到一个`Status::Entity`类并将其用作代表实体.仍然可使用`:with`或者是明确的`represents`来覆盖它.
你可以使用`Grape::Presenters::Presenter`呈现`hash`来保持一致
```ruby
get '/users' do
  present { id: 10, name: :dgz }, with: Grape::Presenters::Presenter
end
```
这个响应会是
```ruby
{
  id:   10,
  name: 'dgz'
}
```
下面代码有相同的效果
```ruby
get '/users' do
  present :id, 10
  present :name, :dgz
end
```
##### 超媒体和Roal
你可以使用Roal和grape-roal的帮助下渲染HAL或者Collection + JSON,它定义了一个自定义JSON格式化工具,并使用Grape `present`关键字显示实体
##### Rabl
你可以在grape-rabl gem的帮助下使用Rabl模板,它可以自定义Grape Rabl格式.
##### Active Model Serializers
你可以在grape-active_model_serializers gem的帮助下使用Active Model Serializers,它可以自定义Grape AMS格式.
##### 发送原始数据或者NO Data
一般情况下,使用binary格式发送原始数据
```ruby
class API < Grape::API
  get '/file' do
    content_type 'application/octet-stream'
    File.binread 'file.bin'
  end
end
```
你可以使用body显示设置响应主体.
```ruby
class API < Grape::API
  get '/' do
    content_type 'text/plain'
    body 'Hello World'
    # return value ignored
  end
end
```
如果没有任何数据或content-type,请使用`body false`返回`204 No Content`
你也可以使用`file`来是响应返回一个文件
```ruby
class API < Grape::API
  get '/' do
    file '/path/to/file'
  end
end
```
如果你想使用`Rack::Chunked`传输文件,请使用`stream`.
```ruby
class API < Grape::API
  get '/' do
    stream '/path/to/file'
  end
end
```
##### 认证
##### 基本和摘要认证
Grape内置了Basic和Digest身份认证(给定`block`在当前`endpoint`的上下文中执行).身份验证适用于当前命名空间和任何子级,但不适用于父级.
```ruby
http_basic do |username, password|
  # verify user's password here
  { 'test' => 'password1' }[username] == password
end
```
```ruby
http_digest({ realm: 'Test Api', opaque: 'app secret' }) do |username|
  # lookup the user's password here
  { 'user1' => 'password1' }[username]
end
```
##### 注册自定义中间件进行身份认证
Grape可以使用自定义中间件进行身份认证.如何实现这些中间件可以看看`Rack::Auth::Basic`或其他类似的实现.
注册中间件你需要主要以下几点.
- `label`-验证者名称以便你后续使用
- `MiddlewareClass`MiddlewareClass用于身份验证
- `option_lookup_proc`带有一个参数的Proc,用于在运行是查找选项(返回的是一个`Array`用于中间件的参数)

例如
```ruby
Grape::Middleware::Auth::Strategies.add(:my_auth, AuthMiddleware, ->(options) { [options[:realm]] } )


auth :my_auth, { realm: 'Test Api'} do |credentials|
  # lookup the user's password here
  { 'user1' => 'password1' }[username]
end
```
使用`warden-oauth2`或者是`rack-oauth2`为OAuth2做支持.

##### 描述和检查API
Grape 的路由可以在运行是反应出来,这对生成文档非常有用
Grape 公开API版本和编译路由的数组.每个路由都包含`route_prefix`,`route_version`,`route_namespace`,`route_method`,`route_path`和`route_params`.你可以通过`route_setting`添加自定义的元数据到路由设置
```ruby
class TwitterAPI < Grape::API
  version 'v1'
  desc 'Includes custom settings.'
  route_setting :custom, key: 'value'
  get do

  end
end
```
在运行时检查路由
```ruby
TwitterAPI::versions # yields [ 'v1', 'v2' ]
TwitterAPI::routes # yields an array of Grape::Route objects
TwitterAPI::routes[0].version # => 'v1'
TwitterAPI::routes[0].description # => 'Includes custom settings.'
TwitterAPI::routes[0].settings[:custom] # => { key: 'value' }
```
注意,在0.15.0版本之后,不推荐使用`Route#route_xyz`方法
请改用`Route#xyz`
请注意`Route#options`和`Route#setting`的区别.
`option`可以从你的路由中引用,它应该通过动词方法的键和值来设置,例如`get`,`post`和`put`.`setting`也可以从你的路由引用,但应通过在`route_setting`上指定键值来设置.
##### 当前路由和端口
可以在API调用`route`检索有关当前路由的信息.
```ruby
class MyAPI < Grape::API
  desc 'Returns a description of a parameter.'
  params do
    requires :id, type: Integer, desc: 'Identity.'
  end
  get 'params/:id' do
    route.route_params[params[:id]] # yields the parameter description
  end
end
```
响应请求的当前端口是API块内的self或者其他地方的`env['api.endpoint']`.端口有一些有趣的属性,例如source,它允许你访问api实现的原始代码块.这对于构建记录日志的中间件特别有用.
```ruby
class ApiLogger < Grape::Middleware::Base
  def before
    file = env['api.endpoint'].source.source_location[0]
    line = env['api.endpoint'].source.source_location[1]
    logger.debug "[api] #{file}:#{line}"
  end
end
```
##### Before 和 After
块可以在每次API调用之前或之后执行,使用`before`,`after`,`before_validation`和`after_validation`.
before和after回调按以下顺序执行:
1. `before`
2. `before_validation`
3. validations
4. `after_validation`
5. API回调
6. `after`

4,5,6步只有在验证成功之后才会执行.
如果在执行回调之前,使用不受支持的HTTP方法(返回HTTP 405)进行资源请求,只有`before`会被执行,其余的回调将会被绕过.
如果发出了出发内置`OPTIONS`处理程序的资源请求,则只会出发`before`和`after`回调.其余的回调将被绕过.
例如使用简单的`before`回调设置header.
```ruby
before do
  header 'X-Robots-Tag', 'noindex'
end
```
##### 命名空间
回调适用于下面命名空间下每个API
```ruby
class MyAPI < Grape::API
  get '/' do
    "root - #{@blah}"
  end

  namespace :foo do
    before do
      @blah = 'blah'
    end

    get '/' do
      "root - foo - #{@blah}"
    end

    namespace :bar do
      get '/' do
        "root - foo - bar - #{@blah}"
      end
    end
  end
end
```
```ruby
GET /           # 'root - '
GET /foo        # 'root - foo - blah'
GET /foo/bar    # 'root - foo - bar - blah'
```
使用before_validation或after_validation时,命名空间上的参数也将可用
```ruby
class MyAPI < Grape::API
  params do
    requires :blah, type: Integer
  end
  resource ':blah' do
    after_validation do
      # if we reach this point validations will have passed
      @blah = declared(params, include_missing: false)[:blah]
    end

    get '/' do
      @blah.class
    end
  end
end
```
```ruby
GET /123        # 'Integer'
GET /foo        # 400 error - 'blah is invalid'
```
##### 版本
在版本块中定时,仅调用该块中定义的路由.
```ruby
class Test < Grape::API
  resource :foo do
    version 'v1', :using => :path do
      before do
        @output ||= 'v1-'
      end
      get '/' do
        @output += 'hello'
      end
    end

    version 'v2', :using => :path do
      before do
        @output ||= 'v2-'
      end
      get '/' do
        @output += 'hello'
      end
    end
  end
end
```
```ruby
GET /foo/v1       # 'v1-hello'
GET /foo/v2       # 'v2-hello'
```
##### 改变响应
在任何回调中使用`present`允许你想响应添加数据.
```ruby
class MyAPI < Grape::API
  format :json

  after_validation do
    present :name, params[:name] if params[:name]
  end

  get '/greeting' do
    present :greeting, 'Hello!'
  end
end
```
```ruby
GET /greeting              # {"greeting":"Hello!"}
GET /greeting?name=Alan    # {"name":"Alan","greeting":"Hello!"}
```
你也可以使用`error!`从任何回调终止并重写它,而不是更改响应,包括`after`.这将导致不调用过程中的所有后续步骤.这包括实际的api调用和任何回调.
##### Anchoring
默认情况下,Grape会锚定所有的请求路径,这意味着请求URL应该从头到尾匹配,否则会返回404 Not Found.但是这有时并不是你想要的,因为并不总是能够预先了解所期望的内容.这是因为默认情况下,Rack-mount将请求从开始到结束进行匹配,或者根本不进行匹配.rails通过在路由中使用`anchor: false`选项解决了这个问题.在Grape中,在定义方法时也可以使用此选项.
例如,当你的API需要获取URL的一部分时
```ruby
class TwitterAPI < Grape::API
  namespace :statuses do
    get '/(*:status)', anchor: false do

    end
  end
end
```
这将匹配所有符合`/statues/`的路径.有一点需要注意`params[:status]`参数仅保存请求url的一部分.幸运的是使用上述路径规范语法并使用上述路径规范语法并使用`PATH_INFO Rack`环境变量,使用`env['PATH_INFO']`可以避免这种情况.
这将保存'/statuses'之后的所有内容.

##### 使用自定义中间件
##### Grape 中间件
你可以使用`Grape::Middleware::Base`自定义中间件.事实上它是从Grape官方中间件继承而来.
例如,你可以写一个中间件,记录程序异常.
```ruby
class LoggingError < Grape::Middleware::Base
  def after
    return unless @app_response && @app_response[0] == 500
    env['rack.logger'].error("Raised error on #{env['PATH_INFO']}")
  end
end
```
除错误情况外,你的中间件可以覆盖如下应用程序响应.
```ruby
class Overwriter < Grape::Middleware::Base
  def after
    [200, { 'Content-Type' => 'text/plain' }, ['Overwritten.']]
  end
end
```
你可以使用`use`添加自定义中间件,这将中间件推入堆栈,你可以使用`insert`,`insert_before`,和`insert_after`控制中间件的插入位置,
```ruby
class CustomOverwriter < Grape::Middleware::Base
  def after
    [200, { 'Content-Type' => 'text/plain' }, [@options[:message]]]
  end
end


class API < Grape::API
  use Overwriter
  insert_before Overwriter, CustomOverwriter, message: 'Overwritten again.'
  insert 0, CustomOverwriter, message: 'Overwrites all other middleware.'

  get '/' do
  end
end
```
##### Rails 中间件
请注意,当你在Rails上使用Grape时,你不必使用rails中间件,因为它已经饱和在您的中间件堆栈中.你只需要实现帮助程序访问特定的`env`变量

##### Remote IP
默认情况下你可以通过`request.ip`获得远程ip,这个远程ip地址是通过Rack获得的.有些需要使用`ActionDispatch::RemoteIp`获取远程IP 遵守rails风格.
添加`gem 'actionpack'`到你的gemfile然后`require 'action_dispath/middleware/remote_ip.rb'`.使用API中的中间件并公开client_ip helper.
详情参阅它的官方文档.
```ruby
class API < Grape::API
  use ActionDispatch::RemoteIp

  helpers do
    def client_ip
      env['action_dispatch.remote_ip'].to_s
    end
  end

  get :remote_ip do
    { ip: client_ip }
  end
end
```
##### 编写测试
##### 使用Rack编写测试
使用`rack-test`并将你的API定义为`app`.
##### RSpec
你可以使用RSpec测试Grape APi通过HTTP请求并检查响应
```ruby
require 'spec_helper'

describe Twitter::API do
  include Rack::Test::Methods

  def app
    Twitter::API
  end

  context 'GET /api/statuses/public_timeline' do
    it 'returns an empty array of statuses' do
      get '/api/statuses/public_timeline'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq []
    end
  end
  context 'GET /api/statuses/:id' do
    it 'returns a status by id' do
      status = Status.create!
      get "/api/statuses/#{status.id}"
      expect(last_response.body).to eq status.to_json
    end
  end
end```

没有通过HTTP GET发送对象数组的标准方法,因此POST JSON 数据并指定正确的内容类型.
```ruby
describe Twitter::API do
  context 'POST /api/statuses' do
    it 'creates many statuses' do
      statuses = [{ text: '...' }, { text: '...'}]
      post '/api/statuses', statuses.to_json, 'CONTENT_TYPE' => 'application/json'
      expect(last_response.body).to eq 201
    end
  end
end
```

##### Airborne
你可以使用其他基于RSpec的框架进行测试,包括Airborne,它使用`rack-test`来发出请求.
```ruby
require 'airborne'

Airborne.configure do |config|
  config.rack_app = Twitter::API
end

describe Twitter::API do
  context 'GET /api/statuses/:id' do
    it 'returns a status by id' do
      status = Status.create!
      get "/api/statuses/#{status.id}"
      expect_json(status.as_json)
    end
  end
end
```

##### MiniTest
```ruby
require 'test_helper'

class Twitter::APITest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Twitter::API
  end

  def test_get_api_statuses_public_timeline_returns_an_empty_array_of_statuses
    get '/api/statuses/public_timeline'
    assert last_response.ok?
    assert_equal [], JSON.parse(last_response.body)
  end

  def test_get_api_statuses_id_returns_a_status_by_id
    status = Status.create!
    get "/api/statuses/#{status.id}"
    assert_equal status.to_json, last_response.body
  end
end
```

##### 用rails编写测试
RSPec
```ruby
describe Twitter::API do
  context 'GET /api/statuses/public_timeline' do
    it 'returns an empty array of statuses' do
      get '/api/statuses/public_timeline'
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq []
    end
  end
  context 'GET /api/statuses/:id' do
    it 'returns a status by id' do
      status = Status.create!
      get "/api/statuses/#{status.id}"
      expect(response.body).to eq status.to_json
    end
  end
end
```
在rails中,HTTP请求测试将进入`spec/requests`组.你可能希望API代码进入`app/api`这样就可以通过在`spec/rails_helper.rb`中添加以下内容来匹配`spec`下的布局.
```ruby
RSpec.configure do |config|
  config.include RSpec::Rails::RequestExampleGroup, type: :request, file_path: /spec\/api/
end
```
##### MiniTest
```ruby
class Twitter::APITest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  test 'GET /api/statuses/public_timeline returns an empty array of statuses' do
    get '/api/statuses/public_timeline'
    assert last_response.ok?
    assert_equal [], JSON.parse(last_response.body)
  end

  test 'GET /api/statuses/:id returns a status by id' do
    status = Status.create!
    get "/api/statuses/#{status.id}"
    assert_equal status.to_json, last_response.body
  end
end
```
##### Stubbing Helpers
由于在定义端口时根据上下文混合帮助程序,所以很难将它们存根或模拟以进行测试.`Grape::Endpoint.before_each`方法可以帮助你定义将在每个个请求之前运行在端口上的行为.
```ruby
describe 'an endpoint that needs helpers stubbed' do
  before do
    Grape::Endpoint.before_each do |endpoint|
      allow(endpoint).to receive(:helper_name).and_return('desired_value')
    end
  end

  after do
    Grape::Endpoint.before_each nil
  end

  it 'stubs the helper' do

  end
end
```
##### 开发环境重新加载api的修改
##### 重新加载Rack 程序
使用<a href="https://github.com/AMar4enko/grape-reload">grape-reload</a>
##### 重新加载rails 程序
添加API路径到`config/application.rb`
```ruby
# Auto-load API and its subdirectories
config.paths.add File.join('app', 'api'), glob: File.join('**', '*.rb')
config.autoload_paths += Dir[Rails.root.join('app', 'api', '*')]
```
创建`config/initializers/reload_api.rb`.
```ruby
if Rails.env.development?
  ActiveSupport::Dependencies.explicitly_unloadable_constants << 'Twitter::API'

  api_files = Dir[Rails.root.join('app', 'api', '**', '*.rb')]
  api_reloader = ActiveSupport::FileUpdateChecker.new(api_files) do
    Rails.application.reload_routes!
  end
  ActionDispatch::Callbacks.to_prepare do
    api_reloader.execute_if_updated
  end
end
```
rails 版本 >=5.1.4,修改这个
```ruby
ActionDispatch::Callbacks.to_prepare do
  api_reloader.execute_if_updated
end
```
变成
```ruby
ActiveSupport::Reloader.to_prepare do
  api_reloader.execute_if_updated
end
```
查看<a href="https://stackoverflow.com/questions/3282655/ruby-on-rails-3-reload-lib-directory-for-each-request/4368838#4368838">StackOverflow #3282655</a>了解更多信息.

##### 性能监控
##### 主动支持的仪器
Grape内置了对ActiveSupport::Notifications的支持,它为仪器的关键部分提供了简单的钩子.
目前支持以下内容
**endpoint_run.grape**
端口的主要执行包括过滤器和渲染.
- endpoint-端口的实例

**endpoint_render.grape**
执行端口的主要内容块
- endpoint - 端口的实例

**endpoint_run_filters.grape**
- endpoint - 端口实例
- filters - 正在执行的过滤器
- Type -过滤器类型

**endpoint_run_validators.grape**
执行验证器
- endpoint - 端口实例
- validators - 正在执行的验证器
- request -请求正在验证

**format_response.grape**
序列化或模板渲染
- env - 请求环境
- format - 格式对象(例如,`Grape::Formatter::Json`)

查看<a href="http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html">ActiveSupport::Notifications documentation </a>了解更多.
