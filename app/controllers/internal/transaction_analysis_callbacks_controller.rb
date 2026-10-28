class Internal::TransactionAnalysisCallbacksController < ActionController::API
  def create
    body = request.raw_post
    return head :unauthorized unless valid_signature?(body)

    payload = JSON.parse(body)
    transaction = Transaction.find_by(id: payload["transaction_id"])
    return head :not_found unless transaction

    if payload["status"] == "failed"
      transaction.fail_analysis!(job_id: payload["job_id"], message: payload["error"])
    else
      transaction.complete_analysis!(job_id: payload["job_id"], result: payload)
    end

    head :no_content
  rescue JSON::ParserError, ActionController::BadRequest
    head :bad_request
  end

  private
    def valid_signature?(body)
      secret = Transaction::AnalysisAuthenticator.read_secret("TRANSACTION_ANALYSIS_CALLBACK_SECRET")
      supplied = request.authorization.to_s.delete_prefix("Bearer ")
      bearer_valid = supplied.bytesize == secret.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(supplied, secret)
      bearer_valid || Transaction::AnalysisAuthenticator.valid?(
        secret: secret,
        timestamp: request.headers["X-Sure-Analysis-Timestamp"],
        signature: request.headers["X-Sure-Analysis-Signature"],
        body: body
      )
    rescue KeyError
      false
    end
end
