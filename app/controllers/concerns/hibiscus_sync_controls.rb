module HibiscusSyncControls
  def sync
    return head :forbidden unless Account.writable_by(Current.user).exists?(id: @account.id)
    result = HibiscusBankClient.start([@account.id])
    return super unless result
    redirect_to account_path(@account), notice: hibiscus_notice(result)
  rescue HibiscusBankClient::Error
    redirect_to account_path(@account), alert: "Hibiscus ist gerade nicht erreichbar. Bitte später erneut versuchen."
  end

  def sync_all
    result = HibiscusBankClient.start(Account.writable_by(Current.user).active.pluck(:id))
    return super unless result
    family.request_plaid_transactions_refreshes_later(source: "AccountsController#sync_all")
    family.sync_later
    redirect_back fallback_location: accounts_path, notice: hibiscus_notice(result)
  rescue HibiscusBankClient::Error
    redirect_back fallback_location: accounts_path, alert: "Hibiscus ist gerade nicht erreichbar. Bitte später erneut versuchen."
  end

  private

  def hibiscus_notice(result)
    return "In Hibiscus läuft bereits ein Bankabruf. Bitte dessen Abschluss abwarten." if result["already_running"]
    result["state"] == "completed" ? "Der letzte Bankabruf wurde gerade abgeschlossen." :
      "Bankabruf in Hibiscus gestartet. Bitte gegebenenfalls in der Bank-App freigeben. Die Daten werden anschließend automatisch übernommen."
  end
end
