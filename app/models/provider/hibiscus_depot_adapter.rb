class Provider::HibiscusDepotAdapter < Provider::Base
  include Provider::InstitutionMetadata
  Provider::Factory.register("HibiscusDepotConnection", self)

  def self.supported_account_types
    %w[Investment]
  end

  def provider_name
    "hibiscus"
  end

  def institution_name
    "ING"
  end

  def institution_domain
    "ing.de"
  end

  def metadata
    super.merge(delivery: "local_publisher", last_imported_at: provider_account.last_imported_at)
  end
end
