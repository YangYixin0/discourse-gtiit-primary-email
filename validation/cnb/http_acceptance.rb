require "json"
require "fileutils"
require "net/http"

class SyntheticHttpSession
  Response = Struct.new(:status, :parsed_body, :headers)
  attr_reader :response

  def initialize
    @cookies = {}
  end

  def get(path, headers: {})
    request(Net::HTTP::Get, path, headers: headers)
  end

  def post(path, params:, headers: {})
    request(Net::HTTP::Post, path, params: params, headers: headers)
  end

  def request(type, path, params: nil, headers: {})
    uri = URI("http://localhost:3000#{path}")
    req = type.new(uri)
    req["Accept"] = "application/json"
    req["X-Requested-With"] = "XMLHttpRequest"
    headers.each { |k,v| req[k] = v }
    req["Cookie"] = @cookies.map { |k,v| "#{k}=#{v}" }.join("; ")
    req.set_form_data(params) if params
    res = Net::HTTP.start(uri.host, uri.port, read_timeout: 120) { |http| http.request(req) }
    Array(res.get_fields("set-cookie")).each do |cookie|
      k,v = cookie.split(";",2).first.split("=",2)
      @cookies[k] = v
    end
    body = JSON.parse(res.body) rescue { "non_json" => true, "content_type" => res['content-type'], "prefix" => res.body.to_s[0,80] }
    @response = Response.new(res.code.to_i, body, res.to_hash.transform_values(&:first).transform_keys { |k| k.split('-').map(&:capitalize).join('-') })
  end
end

fixture = JSON.parse(File.read("/workspace/fixture.json"))
results = []
check = ->(name, condition, detail = {}) do
  results << { name: name, pass: !!condition, detail: detail }
  FileUtils.mkdir_p("/workspace/evidence")
  File.write("/workspace/evidence/http-results.json", JSON.pretty_generate(results))
  puts "#{condition ? 'PASS' : 'FAIL'} #{name} #{detail.to_json}"
  raise name unless condition
end
session_for = ->(username = nil) do
  s = SyntheticHttpSession.new
  if username
    s.get "/session/csrf.json"
    csrf = s.response.parsed_body.fetch("csrf")
    s.post "/session", params: { login: username, password: "Synthetic-Validation-2026!" }, headers: { "X-CSRF-Token" => csrf, "X-Requested-With" => "XMLHttpRequest" }
    check.call("session #{username}", s.response.status == 200 && s.response.parsed_body["error"].nil?, { status: s.response.status })
  end
  s
end
alice = session_for.call("alice")
bob = session_for.call("bob")
anon = session_for.call
paths = ["/u/alice.json", "/u/alice/card.json", "/t/#{fixture['topic_id']}.json"]
field_values = ->(obj) do
  case obj
  when Hash
    obj.flat_map { |k,v| k == "gtiit_primary_email" ? [v] : field_values.call(v) }
  when Array
    obj.flat_map { |v| field_values.call(v) }
  else
    []
  end
end
3.times do |round|
  [[alice,true,"alice"],[anon,false,"anonymous"],[bob,true,"bob"]].each do |s, expected, name|
    paths.each do |path|
      s.get path, headers: { "X-Requested-With" => "XMLHttpRequest" }
      values = field_values.call(s.response.parsed_body)
      check.call("isolation #{round} #{name} #{path}", s.response.status == 200 && (expected ? values.include?("alice@example.test") : values.empty?), { status: s.response.status, field_count: values.size, keys: s.response.parsed_body.keys, non_json: s.response.parsed_body['non_json'], prefix: s.response.parsed_body['prefix'], user_id: s.response.parsed_body.dig("user","id"), cache_control: s.response.headers["Cache-Control"], vary: s.response.headers["Vary"] })
      if expected
        check.call("private cache #{name} #{path}", s.response.headers["Cache-Control"].to_s.include?("private") && s.response.headers["Cache-Control"].to_s.include?("no-store"))
      end
      check.call("secondary excluded #{name} #{path}", !values.include?("alice.secondary@example.test"))
    end
  end
end
[fixture['private_topic_id'],fixture['pm_id']].each do |id|
  [alice,bob,anon].each_with_index do |s,i|
    s.get "/t/#{id}.json"
    check.call("restricted topic #{id} viewer #{i}", i == 0 ? s.response.status == 200 : [403,404].include?(s.response.status), {status:s.response.status})
  end
end
api = ApiKey.create!(user: User.find_by!(username: "bob"), description: "Synthetic isolated validation")
client = UserApiKeyClient.create!(client_id: SecureRandom.hex, application_name: "Synthetic isolated validation")
client.scopes.create!(name: "read")
user_api = UserApiKey.create!(user: User.find_by!(username: "bob"), client: client)
user_api.scopes.create!(name: "read")
begin
  [{"Api-Key"=>api.key},{"User-Api-Key"=>user_api.key}].each_with_index do |headers,i|
    s = session_for.call
    paths.each do |path|
      s.get path, headers: headers
      check.call("API #{i} #{path}", s.response.status == 200 && field_values.call(s.response.parsed_body).empty?, {status:s.response.status})
    end
    [fixture['private_topic_id'],fixture['pm_id']].each do |id|
      s.get "/t/#{id}.json", headers: headers
      check.call("API #{i} restricted #{id}", [403,404].include?(s.response.status) && field_values.call(s.response.parsed_body).empty?, {status:s.response.status})
    end
  end
ensure
  api.destroy!
  user_api.destroy!
  client.destroy!
end

# Measure topic-view loading and post serialization in this process, so SQL can be counted.
[false,true].each do |enabled|
  SiteSetting.gtiit_primary_email_enabled = enabled
  viewer = User.find_by!(username: "bob")
  request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/t/#{fixture['topic_id']}.json"))
  guardian = Guardian.new(viewer, request)
  TopicView.new(fixture['topic_id'], viewer, guardian: guardian)
  queries = []
  view = nil
  serialized = nil
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload
    queries << payload[:sql] if !payload[:cached] && payload[:sql].match?(/\buser_emails\b/i)
  end
  begin
    puts "SQL_POLICY #{GtiitPrimaryEmail::Policy.member?(guardian)} enabled=#{SiteSetting.gtiit_primary_email_enabled}"
    ActiveRecord::Base.uncached do
      view = TopicView.new(fixture['topic_id'], viewer, guardian: guardian)
      serialized = view.posts.map { |post| PostSerializer.new(post, scope: guardian, root: false).as_json.deep_stringify_keys }
    end
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
  posts = serialized
  values = field_values.call(serialized)
  check.call("many author SQL enabled=#{enabled}", enabled ? values.size == posts.size : values.empty?, { posts: posts.size, authors: view.posts.map(&:user_id).uniq.size, email_selects: queries.size, sql: queries })
  check.call("bounded primary email queries", queries.size <= 3, {email_selects:queries.size}) if enabled
end
SiteSetting.gtiit_primary_email_enabled = true
puts "HTTP_ACCEPTANCE_COMPLETE"
