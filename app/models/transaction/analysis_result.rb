class Transaction::AnalysisResult
  STATUSES = %w[completed needs_review].freeze
  CONFIDENCES = %w[high medium low].freeze
  MAX_DOCUMENTS = 20

  class << self
    def normalize(value)
      data = value.to_h.stringify_keys
      status = data["status"].to_s
      status = "needs_review" unless status.in?(STATUSES)

      {
        "status" => status,
        "summary" => text(data["summary"], 2_000),
        "confidence" => confidence(data["confidence"]),
        "merchant" => text(data["merchant"], 255),
        "suggested_category" => text(data["suggested_category"], 255),
        "amount_match" => amount_match(data["amount_match"]),
        "documents" => documents(data["documents"]),
        "reasoning" => text(data["reasoning"], 4_000),
        "warnings" => Array(data["warnings"]).first(20).filter_map { |warning| text(warning, 500) },
        "model" => text(data["model"], 100),
        "workflow_version" => text(data["workflow_version"], 100)
      }.compact
    end

    private
      def text(value, limit)
        value.to_s.strip.first(limit).presence
      end

      def confidence(value)
        normalized = value.to_s.downcase
        normalized.in?(CONFIDENCES) ? normalized : "low"
      end

      def integer(value)
        Integer(value, exception: false)
      end

      def amount_match(value)
        match = value.to_h.stringify_keys
        {
          "booking_cents" => integer(match["booking_cents"]),
          "documents_cents" => integer(match["documents_cents"]),
          "exact" => match["exact"] == true
        }.compact
      end

      def documents(value)
        Array(value).first(MAX_DOCUMENTS).filter_map do |document|
          data = document.to_h.stringify_keys
          id = integer(data["id"])
          next unless id

          {
            "id" => id,
            "title" => text(data["title"], 500) || "Paperless ##{id}",
            "url" => safe_url(data["url"]),
            "date" => safe_date(data["date"]),
            "amount_cents" => integer(data["amount_cents"]),
            "reference_number" => text(data["reference_number"], 255)
          }.compact
        end
      end

      def safe_url(value)
        uri = URI.parse(value.to_s)
        uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
      rescue URI::InvalidURIError
        nil
      end

      def safe_date(value)
        Date.iso8601(value.to_s).iso8601
      rescue Date::Error
        nil
      end
  end
end
