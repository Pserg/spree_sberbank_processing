module Spree
  class SberbankTransaction < Spree::Base

    belongs_to :order

    validates :spree_order_id, :form_url, presence: true

  end
end