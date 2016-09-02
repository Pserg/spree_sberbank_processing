module Spree
  class Gateway::SberbankGateway < Gateway

    preference :api_username, :string
    preference :api_password, :string


  end
end