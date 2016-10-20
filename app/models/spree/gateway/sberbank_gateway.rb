module Spree

  class Gateway::SberbankGateway < Gateway

    preference :api_username, :string
    preference :api_password, :password

    attr_accessor :api_username, :api_password, :server, :test_mode

    REGISTER_URL = 'register.do'
    GET_STATUS_URL = 'getOrderStatus.do'

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
      false
    end

    def payment_profiles_supported?
      false
    end

    def source_required?
      false
    end

    def purchase(amount, sources, gateway_options = {})
    end

    def register_order(order_params)
      @order_id = order_params['order_id']
      @transaction_order_number = order_params['orderNumber']
      @payment_method_id = order_params['payment_method_id']
      commit_url = url + REGISTER_URL
      register_response_processing(commit(commit_url, order_params))
    end

    def get_order_status(order_params)
      commit_url = url + GET_STATUS_URL
      response = commit(commit_url, order_params)
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


    def register_response_processing(response)
      if response.has_key?('errorCode')
        ActiveMerchant::Billing::Response.new(false, 'Sberbank Gateway: Forced failure', { message: "Платеж не может быть обработан. #{response['errorMessage']} "}, {})
        return
      elsif response.has_key?('orderId') && response.has_key?('formUrl')
        transaction = Spree::SberbankTransaction.new(spree_order_id: @order_id, form_url: response['formUrl'],
                                                     transaction_order_number: @transaction_order_number, payment_method_id: @payment_method_id,
                                                     registered_order_id: response['orderId']) unless Spree::SberbankTransaction.where(spree_order_id: @order_id).first
        if transaction
          transaction.save
          ActiveMerchant::Billing::Response.new(true, 'Sberbank Gateway: Forced success', {}, {})
        else
          ActiveMerchant::Billing::Response.new(false, 'Sberbank Gateway: Forced failure', { message: "Такой заказ уже находится в обработке."}, {})
        end
      end
    end

  end
end