require "net/http"
require "json"

class HibiscusBankClient
  class Error < StandardError; end

  def self.request(path, body = nil)
    uri = URI("http://hibiscus-sure:3001" + path)
    req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer " + File.read("/run/secrets/hibiscus-trigger-token").strip
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(body) if body
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 5) { |http| http.request(req) }
    return nil if response.code == "404"
    raise Error, "Hibiscus bridge unavailable" unless response.code.start_with?("2")
    JSON.parse(response.body)
  rescue SystemCallError, IOError, Timeout::Error, JSON::ParserError
    raise Error, "Hibiscus bridge unavailable"
  end

  def self.start(account_ids)
    request("/bank-sync", { account_ids: account_ids })
  end

  def self.visible_status(user)
    result = request("/status")
    return nil unless result && result["account_ids"]
    allowed = Account.accessible_by(user).pluck(:id)
    return nil unless (result["account_ids"] - allowed).empty?
    result
  rescue Error
    nil
  end
end
