# Local, read-only publisher; no bank credentials are stored in this record.
class HibiscusDepotConnection < ApplicationRecord
  belongs_to :family
  has_one :account_provider, as: :provider, dependent: :destroy
  has_one :account, through: :account_provider
  validates :hibiscus_account_id, presence: true, uniqueness: { scope: :family_id }
end
