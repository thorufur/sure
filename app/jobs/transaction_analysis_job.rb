require "net/http"

class TransactionAnalysisJob < ApplicationJob
  class DispatchError < StandardError; end

  queue_as :high_priority
  retry_on DispatchError, wait: :polynomially_longer, attempts: 3 do |job, error|
    transaction = Transaction.find_by(id: job.arguments.first)
    transaction&.fail_analysis!(job_id: job.arguments.second, message: error.message)
  end

  def perform(transaction_id, job_id)
    transaction = Transaction.includes(:tags, :merchant, :category, entry: :account).find(transaction_id)
    return unless transaction.analysis["job_id"] == job_id

    transaction.mark_analysis_running!(job_id)
    body = JSON.generate(transaction.analysis_payload)
    response = dispatch(body)
    return if response.code.to_i.between?(200, 299)

    raise DispatchError, "n8n returned HTTP #{response.code}"
  rescue KeyError, URI::InvalidURIError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => error
    raise DispatchError, error.message
  end

  private
    def dispatch(body)
      uri = URI.parse(ENV.fetch("TRANSACTION_ANALYSIS_WEBHOOK_URL"))
      timestamp = Time.current.to_i.to_s
      secret = Transaction::AnalysisAuthenticator.read_secret("TRANSACTION_ANALYSIS_REQUEST_SECRET")

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{secret}"
      request["X-Sure-Analysis-Timestamp"] = timestamp
      request["X-Sure-Analysis-Signature"] = Transaction::AnalysisAuthenticator.signature(
        secret: secret,
        timestamp: timestamp,
        body: body
      )
      request.body = body

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) do |http|
        http.request(request)
      end
    end
end
