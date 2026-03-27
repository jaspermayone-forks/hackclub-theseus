FactoryBot.define do
  factory :warehouse_sku, class: "Warehouse::SKU" do
    sequence(:sku) { |n| "Test/Sku/#{n}" }
    sequence(:name) { |n| "Test SKU #{n}" }
    enabled { true }
    category { :hardware }
  end
end
