Spree::CheckoutController.class_eval do
  before_action :confirm_order
  before_action :process_order, :only => [:update]

  ERRORS = {'0' => {0 => "Заказ находится в процессе оплаты. Если вы случайно закрыли страницу оплаты
                      пройдите по ссылке "},
            '7' => {6 => "Оплата заказа отменена. Выберите другой способ оплаты "}}

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
    if response.success?
      redirect_to_payment_page
    else
      protect_finalization
    end
  end

  def redirect_to_payment_page
    @payment.state = 'pending'
    @payment.save
    if get_transaction
      @order.save
      redirect_to get_transaction.form_url
    else
      protect_finalization
    end
  end

  def confirm_order
    return unless @order.state == 'payment' && @order.payments.first
    @payment = Spree::Payment.where(order_id: @order.id).first
    return unless @payment.state = 'pending' || get_transaction
    payment_method = Spree::PaymentMethod.where(id: @payment.payment_method_id).first
    return unless get_transaction
    order_params = {'userName' => payment_method.preferences[:api_username], 'password' => payment_method.preferences[:api_password],'orderId' => get_transaction.registered_order_id}

    begin
      retries ||= 0
      response = payment_method.get_order_status(order_params)

      if !response
        logger.fatal "Failed to get response. Order number: #{order.number} Registered order id: #{get_transaction.registered_order_id}"
        raise "Failed to get response"
      elsif response['ErrorCode'] == '0' && response['OrderStatus'] == 1 || response['OrderStatus'] == 0
        logger.fatal "Failed to get right order status. Error code: #{response['ErrorCode']} Order status: #{response['OrderStatus']}  Order number: #{order.number} Registered order id: #{get_transaction.registered_order_id}"
        raise "Failed to get right order status"
      end

    rescue
      sleep(retries)
      retry if (retries += 1) < 4
    end

    if response['ErrorCode'] == '0' && response['OrderStatus'] == 2
      @payment.state = 'completed'
      @payment.save
      @order.update(state: 'complete', completed_at: Time.now, payment_state: 'paid')
      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      @order.deliver_order_confirmation_email
      redirect_to completion_route
    else
      response_error_handling(response['ErrorCode'], response['OrderStatus'], response['ErrorMessage'])
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

  def response_error_handling(code, status, message)
    if ERRORS.include?(code)
      flash['error'] = ERRORS[code][status] if ERRORS[code][status]
      flash['error'] += get_transaction.form_url if status == 0
    else
      flash['error'] = "Ошибка обработки платежа: #{message}. Выбирете другой способ оплаты"
    end
      redirect_to checkout_state_path('payment') && return
  end

end


