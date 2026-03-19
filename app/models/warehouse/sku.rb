# == Schema Information
#
# Table name: warehouse_skus
#
#  id                          :bigint           not null, primary key
#  actual_cost_to_hc           :decimal(, )
#  ai_enabled                  :boolean
#  average_po_cost             :decimal(, )
#  category                    :integer
#  country_of_origin           :string
#  customs_description         :text
#  declared_unit_cost_override :decimal(, )
#  description                 :text
#  enabled                     :boolean
#  hs_code                     :string
#  in_stock                    :integer
#  inbound                     :integer
#  name                        :string
#  sku                         :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  zenventory_id               :string
#
# Indexes
#
#  index_warehouse_skus_on_sku  (sku) UNIQUE
#
class Warehouse::SKU < ApplicationRecord
  has_paper_trail

  scope :in_inventory, -> { where.not(in_stock: nil, inbound: nil) }
  scope :backordered, -> { where("in_stock < 0") }

  def declared_unit_cost = declared_unit_cost_override || average_po_cost || 0.0

  enum :category, {
    sticker: 0,
    poster: 1,
    card: 2,
    flyer: 3,
    other_printed_material: 4,
    hardware: 5,
    book: 6,
    swag: 7,
    grant: 8,
    prize: 9,
  }

  include HasTableSync
  include HasZenventoryUrl

  has_table_sync ENV["AIRTABLE_THESEUS_BASE"],
                 ENV["AIRTABLE_SKUS_TABLE"],
                 {
                   sku: :sku,
                   name: :name,
                   category: ->(_) { category.to_s.humanize },
                   enabled: :enabled,
                   declared_unit_cost: :declared_unit_cost,
                   actual_cost_to_hc: :actual_cost_to_hc,
                   in_stock: :in_stock,
                   inbound: :inbound,
                 }

  has_zenventory_url "https://app.zenventory.com/admin/item-details/%s/basic", :zenventory_id

  def sync_to_zenventory!
    params = {
      sku: sku,
      description: name,
      category: category&.to_s&.humanize,
      active: enabled || false,
      unitCost: declared_unit_cost,
      userField1: country_of_origin,
      userField2: hs_code,
    }.compact

    if zenventory_id.present?
      Zenventory.update_item(zenventory_id, params)
    else
      response = Zenventory.create_item(params)
      update!(zenventory_id: response[:id].to_s)
    end
  end
end
