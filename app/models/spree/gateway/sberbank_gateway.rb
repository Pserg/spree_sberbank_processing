module Spree
  class Gateway::SberbankGateway < Gateway

    preference :api_username, :string
    preference :api_password, :string

    def authorize(money, credit_card, options = {})

    end



  end
end