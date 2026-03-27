class Warehouse::InventoryAlertMailer < GenericTextMailer
  def cost_alert(zero_cost_items:, costless_skus:)
    @zero_cost_items = zero_cost_items
    @costless_skus = costless_skus
    @subject = "[theseus] [warehouse] #{@zero_cost_items.length + @costless_skus.length} SKU cost #{"problem".pluralize(@zero_cost_items.length + @costless_skus.length)}"
    @recipient = "nora@hackclub.com"

    mail to: "dinobox@hackclub.com"
  end
end
