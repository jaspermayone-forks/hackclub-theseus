# == Schema Information
#
# Table name: letter_queues
#
#  id                         :bigint           not null, primary key
#  include_qr_code            :boolean          default(TRUE)
#  letter_height              :decimal(, )
#  letter_mailing_date        :date
#  letter_processing_category :integer
#  letter_return_address_name :string
#  letter_weight              :decimal(, )
#  letter_width               :decimal(, )
#  name                       :string
#  postage_type               :string
#  slug                       :string
#  tags                       :citext           default([]), is an Array
#  template                   :string
#  type                       :string
#  user_facing_title          :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  hcb_payment_account_id     :bigint
#  letter_mailer_id_id        :bigint
#  letter_return_address_id   :bigint
#  user_id                    :bigint           not null
#  usps_payment_account_id    :bigint
#
# Indexes
#
#  index_letter_queues_on_hcb_payment_account_id    (hcb_payment_account_id)
#  index_letter_queues_on_letter_mailer_id_id       (letter_mailer_id_id)
#  index_letter_queues_on_letter_return_address_id  (letter_return_address_id)
#  index_letter_queues_on_type                      (type)
#  index_letter_queues_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (hcb_payment_account_id => hcb_payment_accounts.id)
#  fk_rails_...  (letter_mailer_id_id => usps_mailer_ids.id)
#  fk_rails_...  (letter_return_address_id => return_addresses.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (usps_payment_account_id => usps_payment_accounts.id)
#
class Letter::Queue < ApplicationRecord
  has_paper_trail

  belongs_to :user
  has_many :letters, foreign_key: :letter_queue_id
  has_many :letter_batches, class_name: "Letter::Batch", foreign_key: :letter_queue_id
  belongs_to :letter_mailer_id, class_name: "USPS::MailerId", foreign_key: "letter_mailer_id_id", optional: true
  belongs_to :letter_return_address, class_name: "ReturnAddress", optional: true

  before_validation :set_slug, on: :create

  validates :slug, uniqueness: true, presence: true
  validates :letter_height, :letter_width, :letter_weight, presence: true, numericality: { greater_than: 0 }
  validates :letter_mailer_id, presence: true
  validates :letter_return_address, presence: true, on: :process
  validates :letter_processing_category, presence: true
  validates :tags, presence: true, length: { minimum: 1 }
  validate :type_cannot_be_changed, on: :update

  def create_letter!(address, params)
    letter = letters.build(
      address:,
      height: letter_height,
      width: letter_width,
      weight: letter_weight,
      return_address: letter_return_address,
      return_address_name: letter_return_address_name,
      usps_mailer_id: letter_mailer_id,
      processing_category: letter_processing_category,
      tags: tags,
      aasm_state: "queued",
      **params,
    )
    letter.save!
    letter
  end

  def make_batch(user:, limit: nil)
    ActiveRecord::Base.transaction do
      batch = letter_batches.build(
        aasm_state: :fields_mapped,
        letter_height: letter_height,
        letter_width: letter_width,
        letter_weight: letter_weight,
        letter_processing_category: letter_processing_category,
        letter_mailer_id_id: letter_mailer_id_id,
        letter_return_address_id: letter_return_address_id,
        letter_return_address_name: letter_return_address_name,
        user_facing_title: user_facing_title,
        tags: tags,
        letter_queue_id: id,
        user: user,
      )
      batch.save!
      queued_letters = letters.queued
      queued_letters = queued_letters.limit(limit) if limit.present?
      queued_letters.each do |letter|
        letter.batch_id = batch.id
        letter.batch_from_queue
        letter.save!
      end
      batch
    end
  end

  def to_param
    slug
  end

  private

  def set_slug
    self.slug = self.name.parameterize
  end

  def type_cannot_be_changed
    if type_changed? && persisted?
      errors.add(:type, "cannot be changed after creation")
    end
  end
end
