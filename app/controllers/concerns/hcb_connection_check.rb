module HCBConnectionCheck
  extend ActiveSupport::Concern

  included do
    helper_method :hcb_connection_invalidated?
  end

  private

  def hcb_connection_invalidated?
    user_signed_in? && current_user.hcb_connection_invalidated?
  end
end
