Spree::CheckoutController.class_eval do

  after_filter :redirect_to_processing_page, only: [:update]

  private

  def redirect_to_processing_page
    return unless (params[:state] == "payment")
    byebug
    #redirect_to '127.0.0.1:3000'
  end

end

