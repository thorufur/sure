class Transaction::AnalysisAuthenticator
  MAX_AGE = 5.minutes

  class << self
    def signature(secret:, timestamp:, body:)
      "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    end

    def valid?(secret:, timestamp:, body:, signature:, now: Time.current)
      parsed = Time.at(Integer(timestamp, exception: false) || 0)
      return false if (now - parsed).abs > MAX_AGE

      expected = self.signature(secret: secret, timestamp: timestamp, body: body)
      signature.present? && signature.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end

    def read_secret(environment_key)
      file = ENV["#{environment_key}_FILE"]
      value = file.present? ? File.read(file).strip : ENV[environment_key].to_s
      raise KeyError, "#{environment_key} is not configured" if value.blank?

      value
    end
  end
end
