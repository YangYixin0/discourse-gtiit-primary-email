# frozen_string_literal: true

module GtiitPrimaryEmail
  module Policy
    def self.member?(guardian)
      request = guardian&.request
      user = guardian&.user
      return false unless request && guardian.authenticated? && user.id.positive?
      return false unless user.active? && user.approved? && !user.staged? && !user.suspended?

      env = request.env
      return false if env[Auth::DefaultCurrentUserProvider::API_KEY_ENV]
      return false if env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]

      true
    end

    def self.profile?(guardian, user)
      member?(guardian) && user && user.id.positive? && !user.staged? &&
        guardian.can_see_profile?(user)
    end

    def self.post?(guardian, post)
      member?(guardian) && post.user && post.user.id.positive? && !post.user.staged? &&
        guardian.can_see_post?(post) && guardian.can_see_topic?(post.topic)
    end
  end
end
