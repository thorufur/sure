require "test_helper"

class TransactionAnalysisJobTest < ActiveJob::TestCase
  setup do
    @transaction = transactions(:one)
    @job_id = @transaction.queue_analysis!(requested_by: users(:family_admin))
    @old_environment = {
      "TRANSACTION_ANALYSIS_WEBHOOK_URL" => ENV["TRANSACTION_ANALYSIS_WEBHOOK_URL"],
      "TRANSACTION_ANALYSIS_REQUEST_SECRET" => ENV["TRANSACTION_ANALYSIS_REQUEST_SECRET"],
      "TRANSACTION_ANALYSIS_CALLBACK_URL" => ENV["TRANSACTION_ANALYSIS_CALLBACK_URL"]
    }
    ENV["TRANSACTION_ANALYSIS_WEBHOOK_URL"] = "https://n8n.example/webhook/sure-analysis"
    ENV["TRANSACTION_ANALYSIS_REQUEST_SECRET"] = "request-secret"
    ENV["TRANSACTION_ANALYSIS_CALLBACK_URL"] = "https://sure.example/internal/transaction_analysis_callbacks"
  end

  teardown do
    @old_environment.each { |key, value| ENV[key] = value }
  end

  test "sends a signed payload and marks the analysis running" do
    request = stub_request(:post, "https://n8n.example/webhook/sure-analysis")
      .with do |incoming|
        timestamp = incoming.headers["X-Sure-Analysis-Timestamp"]
        signature = incoming.headers["X-Sure-Analysis-Signature"]
        payload = JSON.parse(incoming.body)

        payload["job_id"] == @job_id &&
          incoming.headers["Authorization"] == "Bearer request-secret" &&
          Transaction::AnalysisAuthenticator.valid?(
            secret: "request-secret", timestamp: timestamp, body: incoming.body, signature: signature
          )
      end
      .to_return(status: 202, body: "")

    TransactionAnalysisJob.perform_now(@transaction.id, @job_id)

    assert_requested request
    assert_equal "running", @transaction.reload.analysis_status
  end
end
