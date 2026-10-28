require "test_helper"

class Internal::TransactionAnalysisCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = transactions(:one)
    @job_id = @transaction.queue_analysis!(requested_by: users(:family_admin))
    @old_secret = ENV["TRANSACTION_ANALYSIS_CALLBACK_SECRET"]
    ENV["TRANSACTION_ANALYSIS_CALLBACK_SECRET"] = "callback-secret"
  end

  teardown do
    ENV["TRANSACTION_ANALYSIS_CALLBACK_SECRET"] = @old_secret
  end

  test "accepts a signed result" do
    body = JSON.generate(
      transaction_id: @transaction.id,
      job_id: @job_id,
      status: "completed",
      summary: "Invoice found",
      confidence: "high"
    )

    post internal_transaction_analysis_callbacks_url,
         params: body,
         headers: signed_headers(body)

    assert_response :no_content
    assert_equal "completed", @transaction.reload.analysis_status
  end

  test "rejects an invalid signature" do
    body = JSON.generate(transaction_id: @transaction.id, job_id: @job_id, status: "completed")

    post internal_transaction_analysis_callbacks_url,
         params: body,
         headers: { "CONTENT_TYPE" => "application/json", "X-Sure-Analysis-Timestamp" => Time.current.to_i.to_s,
                    "X-Sure-Analysis-Signature" => "sha256=invalid" }

    assert_response :unauthorized
    assert_equal "queued", @transaction.reload.analysis_status
  end

  test "accepts the internal bearer credential used by n8n" do
    body = JSON.generate(
      transaction_id: @transaction.id,
      job_id: @job_id,
      status: "needs_review",
      summary: "Manual review needed",
      confidence: "low"
    )

    post internal_transaction_analysis_callbacks_url,
         params: body,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer callback-secret" }

    assert_response :no_content
    assert_equal "needs_review", @transaction.reload.analysis_status
  end

  private
    def signed_headers(body)
      timestamp = Time.current.to_i.to_s
      {
        "CONTENT_TYPE" => "application/json",
        "X-Sure-Analysis-Timestamp" => timestamp,
        "X-Sure-Analysis-Signature" => Transaction::AnalysisAuthenticator.signature(
          secret: "callback-secret", timestamp: timestamp, body: body
        )
      }
    end
end
