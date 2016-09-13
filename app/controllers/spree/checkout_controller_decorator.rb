Spree::CheckoutController.class_eval do
  before_action :confirm_order
  before_action :process_order, :only => [:update]

  def process_order
    return unless (params[:state] == 'payment') && Spree::PaymentMethod.where(id: params[:order][:payments_attributes][0]["payment_method_id"].to_i).first.type == 'Spree::Gateway::SberbankGateway'
    payment_method = Spree::PaymentMethod.where(id: params[:order][:payments_attributes][0]["payment_method_id"].to_i).first
    @payment = Spree::Payment.new(amount: @order.amount, order_id: @order.id, payment_method_id: payment_method.id, state: "checkout")
    @payment.save
    amount = @order.amount.to_f
    amount *= 100

    order_params = {'userName' => payment_method.preferences[:api_username], 'password' => payment_method.preferences[:api_password],
                    'orderNumber' => "#{@order.number}-#{rand(1..9)}#{rand(1..9)}#{rand(1..9)}", 'returnUrl' => "http://#{params[:return_url]}", 'amount' => amount.to_i,
                    'order_id' => @order.id, 'payment_method_id' => params[:payment_method].to_i}
    response = payment_method.register_order(order_params)
    redirect_to_payment_page if response.success?
    protect_finalization
  end

  def redirect_to_payment_page
    @payment.state = 'pending'
    @payment.save
    if get_transaction
      redirect_to get_transaction.form_url
      return
    else
      protect_finalization
    end
  end

  def confirm_order
    return unless @order.state == 'payment' && @order.payments.first
    @payment = Spree::Payment.where(order_id: @order.id).first
    return unless @payment.state = 'pending' || get_transaction.nil?
    payment_method = Spree::PaymentMethod.where(id: @payment.payment_method_id).first
    order_params = {'userName' => payment_method.preferences[:api_username], 'password' => payment_method.preferences[:api_password],'orderId' => get_transaction.registered_order_id}
    response = payment_method.get_order_status(order_params)
    if response['ErrorCode'] == '0' && response['OrderStatus'] == '2'
      @payment.state = 'completed' && @payment.save
      @order.update(state: 'complete', completed_at: Time.now, payment_state: 'paid')
      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to completion_route
    elsif response['ErrorCode'] != '0' && response['OrderStatus'] != '2'
      flash[:error] = "Ошибка обработки платежа: #{response['ErrorMessage']} "
      redirect_to checkout_state_path('payment') && return
    else
      flash[:error] = "Ошибка. Выбирете другой способ оплаты"
      redirect_to checkout_state_path('payment') && return
    end
  end

  def get_transaction
    Spree::SberbankTransaction.where(spree_order_id: @order.id).first
  end

  def protect_finalization
    @order.update(state: 'delivery')
    flash[:error] = "Ошибка регистрации платежа."
    redirect_to checkout_state_path('delivery') && return
  end

end


