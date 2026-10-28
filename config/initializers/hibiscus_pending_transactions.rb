# Hibiscus flags pending bank transactions under its own provider payload.
# Register that provider with Sure so pending entries are excluded from posted
# balances and use Sure's normal pending-transaction presentation.
Rails.application.config.to_prepare do
  unless Transaction::PENDING_PROVIDERS.include?("hibiscus")
    providers = (Transaction::PENDING_PROVIDERS + [ "hibiscus" ]).freeze
    Transaction.send(:remove_const, :PENDING_PROVIDERS)
    Transaction.const_set(:PENDING_PROVIDERS, providers)

    pending_check_sql = providers
      .map { |provider| "(t.extra -> '#{provider}' ->> 'pending')::boolean = true" }
      .join(" OR ")
    Transaction.send(:remove_const, :PENDING_CHECK_SQL)
    Transaction.const_set(:PENDING_CHECK_SQL, pending_check_sql.freeze)
  end
end
