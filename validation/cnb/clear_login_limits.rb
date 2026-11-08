# Only the loopback login counters in this disposable synthetic environment.
%w[127.0.0.1 ::1].each do |ip|
  RateLimiter.new(nil, "login-hr-#{ip}", SiteSetting.max_logins_per_ip_per_hour, 1.hour).clear!
  RateLimiter.new(nil, "login-min-#{ip}", SiteSetting.max_logins_per_ip_per_minute, 1.minute).clear!
end
puts "SYNTHETIC_LOOPBACK_LOGIN_COUNTERS_CLEARED"
