require "test_helper"

class Transaction::AnalysisAuthenticatorTest < ActiveSupport::TestCase
  test "accepts a current valid signature" do
    timestamp = Time.current.to_i.to_s
    signature = Transaction::AnalysisAuthenticator.signature(secret: "secret", timestamp: timestamp, body: "body")

    assert Transaction::AnalysisAuthenticator.valid?(
      secret: "secret", timestamp: timestamp, body: "body", signature: signature
    )
  end

  test "rejects changed payloads and old timestamps" do
    timestamp = 10.minutes.ago.to_i.to_s
    signature = Transaction::AnalysisAuthenticator.signature(secret: "secret", timestamp: timestamp, body: "body")

    refute Transaction::AnalysisAuthenticator.valid?(
      secret: "secret", timestamp: timestamp, body: "changed", signature: signature
    )
    refute Transaction::AnalysisAuthenticator.valid?(
      secret: "secret", timestamp: timestamp, body: "body", signature: signature
    )
  end
end
