require 'faraday'

module SendGrid
  class Batch
    attr_accessor :api_user, :api_key, :protocol, :host, :port, :url,
                  :user_agent, :id
    attr_writer :adapter, :conn, :raise_exceptions

    def initialize(params = {})
      self.api_user         = params.fetch(:api_user, nil)
      self.api_key          = params.fetch(:api_key, nil)
      self.protocol         = params.fetch(:protocol, 'https')
      self.host             = params.fetch(:host, 'api.sendgrid.com')
      self.port             = params.fetch(:port, nil)
      self.url              = params.fetch(:url, protocol + '://' + host + (port ? ":#{port}" : ''))
      self.adapter          = params.fetch(:adapter, adapter)
      self.conn             = params.fetch(:conn, conn)
      self.user_agent       = params.fetch(:user_agent, "sendgrid/#{SendGrid::VERSION};ruby")
      self.raise_exceptions = params.fetch(:raise_exceptions, true)
      self.id               = params.fetch(:id, id)
      yield self if block_given?
    end

    def generate
      res = conn.post do |req|
        req.url('/v3/mail/batch')

        # Check if using username + password or API key
        if api_user
          # Username + password
          req.headers['Authorization'] = "Basic #{ Base64.encode64(api_user + ':' + api_key) }"
        else
          # API key
          req.headers['Authorization'] = "Bearer #{api_key}"
        end

        req.body = {}
      end

      fail SendGrid::Exception, res.body if raise_exceptions? && res.status != 201

      sg_res = SendGrid::Response.new(code: res.status, headers: res.headers, body: res.body)
      self.id = sg_res.body['batch_id']
      id
    end

    def cancel
      fail SendGrid::Exception, 'Batch has no ID' if raise_exceptions? && !id

      res = conn.post do |req|
        req.url('/v3/user/scheduled_sends')

        # Check if using username + password or API key
        if api_user
          # Username + password
          req.headers['Authorization'] = "Basic #{ Base64.encode64(api_user + ':' + api_key) }"
        else
          # API key
          req.headers['Authorization'] = "Bearer #{api_key}"
        end
        req.headers['Content-Type'] = 'application/json'
        req.body = { batch_id: id, status: 'cancel' }.to_json
      end

      fail SendGrid::Exception, res.body if raise_exceptions? && res.status != 201

      SendGrid::Response.new(code: res.status, headers: res.headers, body: res.body)
    end

    def conn
      @conn ||= Faraday.new(url: url) do |conn|
        conn.request :multipart
        conn.request :url_encoded
        conn.adapter adapter
      end
    end

    def adapter
      @adapter ||= Faraday.default_adapter
    end

    def raise_exceptions?
      @raise_exceptions
    end
  end
end
