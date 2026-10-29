class Transaction::AnalysisNote
  START_MARKER = "--- KI-Analyse ---"
  END_MARKER = "--- Ende KI-Analyse ---"
  BLOCK_PATTERN = /(?:\A|\n)#{Regexp.escape(START_MARKER)}\n.*?\n#{Regexp.escape(END_MARKER)}(?=\n|\z)/m

  class << self
    def replace(notes, content)
      base = notes.to_s.sub(BLOCK_PATTERN, "").strip
      block = [ START_MARKER, content.to_s.strip, END_MARKER ].join("\n")
      [ base.presence, block ].compact.join("\n\n")
    end

    def without_analysis(notes)
      notes.to_s.sub(BLOCK_PATTERN, "").strip
    end

    def extract(notes)
      match = notes.to_s.match(BLOCK_PATTERN)
      return unless match

      match[0].sub(/\A\n?#{Regexp.escape(START_MARKER)}\n/, "")
              .sub(/\n#{Regexp.escape(END_MARKER)}\z/, "")
              .strip
    end

    def from_result(result)
      lines = []
      lines << result["summary"] if result["summary"].present?

      match = result["amount_match"] || {}
      if match["booking_cents"] && match["documents_cents"]
        verdict = match["exact"] ? "vollständig passend" : "abweichend"
        lines << "Betragsprüfung: #{verdict} (Buchung #{money(match["booking_cents"])}; Dokumente #{money(match["documents_cents"])})"
      end

      Array(result["documents"]).each do |document|
        label = document["title"].presence || "Paperless ##{document["id"]}"
        label += " (#{money(document["amount_cents"])})" if document["amount_cents"]
        label += " — Referenz: #{document["reference_number"]}" if document["reference_number"].present?
        lines << [ label, document["url"] ].compact.join(": ")
      end

      lines << "Analysiert am: #{I18n.l(Time.current, format: :short)}"
      lines.join("\n").presence
    end

    private
      def money(cents)
        ApplicationController.helpers.number_to_currency(cents.to_i / 100.0, unit: "€", format: "%n %u", separator: ",", delimiter: ".")
      end
  end
end
