module Spree

  class Gateway::SberbankGateway < Gateway

    preference :api_username, :string
    preference :api_password, :password

    attr_accessor :api_username, :api_password, :server, :test_mode, :credit_card

    REGISTER_URL = 'register.do'

    def provider_class
      self.class
    end

    def method_type
      'sberbankgateway'
    end

    def url
      if self.preferences[:test_mode]
        'https://3dsec.sberbank.ru/payment/rest/'
      else
        'https://securepayments.sberbank.ru/payment/rest/'
      end
    end

    def auto_capture?
      true
    end

    def payment_profiles_supported?
      false
    end

    def source_required?
      true
    end

    def purchase(amount, sources, gateway_options = {})
      @credit_card = sources
      params = {'userName' => self.preferences[:api_username], 'password' => self.preferences[:api_password], 'orderNumber' => gateway_options[:order_id], 'returnUrl' => sources.cc_type, 'amount' => amount }
      commit_url = url + REGISTER_URL
      response_processing(commit(commit_url, params))
    end

    private

    def commit(url, request)
      http = initial_http(url)
      req = prepare_request(url, request)
      JSON.parse(http.request(req).body)
    end

    def prepare_request(url, request)
      req = Net::HTTP::Post.new(url)
      req.content_type = "application/x-www-form-urlencoded"
      data = URI.encode_www_form(request)
      req.body = data
      req
    end

    def initial_http(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http
    end


    def response_processing(response)
      if response.has_key?('errorCode')
        ActiveMerchant::Billing::Response.new(false, 'Sberbank Gateway: Forced failure', { message: "Платеж не может быть обработан. #{response['errorMessage']} "}, {})
      elsif response.has_key?('orderId') && response.has_key?('formUrl')
        @credit_card.name = response['formUrl']
        @credit_card.save
        ActiveMerchant::Billing::Response.new(true, 'Sberbank Gateway: Forced success', {}, {})
      end
    end

  end
end