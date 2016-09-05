module Spree
  class Gateway::SberbankGateway < Gateway

    preference :api_username, :string
    preference :api_password, :password

    attr_accessor :api_username, :api_password, :server, :test_mode

    def provider_class
      Spree::Gateway::SberbankGateway
    end

    def url
      if :test_mode
        'https://3dsec.sberbank.ru/payment/rest/'
      else
        'https://securepayments.sberbank.ru/payment/rest/'
      end
    end



    def purchase

    end

  end
end