module RespondHelper
  def generate_success_response(response_body, code = 200)
    build_response_message_body(code, {}, response_body)
  end

  def generate_error_response(error, code = 500)
    error_data = {
      'error-code'  => code,
      'message'     => error.message
    }
    if Rails.env.development?
      Rails.logger.info(error.backtrace.join("\n"))
    end
    build_response_message_body(code, error_data, {})
  end


  private

  def request_info

    headers = current_request.env.select {|k,v| k.start_with? 'HTTP_'}
      .collect {|pair| [pair[0].sub(/^HTTP_/, ''), pair[1]]}
      .collect {|pair| pair.join(": ") << "<br>"}
      .sort

    {
      'href'         => current_request.url,
      'headers'      => headers,
      'query-params' => current_request.query_string,
      'body'         => current_request.body.read
    }
  end

  def current_request
    @request ||= Grape::Request.new(self.env)
  end

  def build_response(body, status, headers = {})
    Rack::Response.new(body, status, headers)
  end

  def build_response_message_body(code, error_data, response_body)
    {
      'meta' => {
        'code' => code,
        'error' => error_data,
        "x-server-current-time" => Time.now
      },
      'request' => request_info,
      'response' => response_body
    }
  end
end
