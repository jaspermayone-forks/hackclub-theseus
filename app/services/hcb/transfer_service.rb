class HCB::TransferService
  attr_reader :hcb_payment_account, :amount_cents, :name, :memo, :errors

  def initialize(hcb_payment_account:, amount_cents:, name:, memo: nil)
    @hcb_payment_account = hcb_payment_account
    @amount_cents = amount_cents
    @name = name
    @memo = memo
    @errors = []
  end

  def call
    return failure("No HCB payment account provided") unless hcb_payment_account
    return failure("Amount must be positive") unless amount_cents.positive?

    transfer = hcb_payment_account.create_disbursement!(
      amount_cents: amount_cents,
      name: name,
      memo: memo,
    )

    transfer
  rescue OAuth2::Error => e
    hcb_payment_account.oauth_connection&.invalidate!
    failure("HCB connection expired — please relink your account")
  rescue HCB::OauthConnectionInvalidatedError
    failure("HCB connection has been invalidated — please relink your account")
  rescue HCBV4::APIError => e
    failure("HCB disbursement failed: #{e.message}")
  rescue => e
    failure("Transfer failed: #{e.message}")
  end

  private

  def failure(message)
    @errors << message
    false
  end
end
