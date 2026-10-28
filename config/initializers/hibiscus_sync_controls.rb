Rails.application.config.to_prepare do
  AccountsController.prepend(HibiscusSyncControls) unless AccountsController < HibiscusSyncControls
end

Rails.application.routes.append do
  get "/hibiscus_sync/status", to: "hibiscus_sync_status#show", as: :hibiscus_sync_status
end
