# frozen_string_literal: true

require "rails_helper"

RSpec.describe TopicsController do
  fab!(:viewer) { Fabricate(:user, trust_level: 2) }
  fab!(:post)

  before { SiteSetting.gtiit_primary_email_enabled = true }

  describe "#show" do
    it "includes the author primary email in the post stream for a member" do
      sign_in(viewer)

      get "/t/#{post.topic_id}.json"

      expect(response.status).to eq(200)
      posts = response.parsed_body.dig("post_stream", "posts")
      expect(posts.find { |entry| entry["id"] == post.id }["gtiit_primary_email"]).to eq(
        post.user.email,
      )
    end

    it "omits the field from an anonymous post stream" do
      SiteSetting.login_required = false

      get "/t/#{post.topic_id}.json"

      expect(response.status).to eq(200)
      response
        .parsed_body
        .dig("post_stream", "posts")
        .each { |entry| expect(entry).not_to have_key("gtiit_primary_email") }
      expect(response.body).not_to include(post.user.email)
    end

    it "rejects access to a private topic by an unrelated member" do
      private_post = Fabricate(:private_message_post)
      sign_in(viewer)

      get "/t/#{private_post.topic_id}.json"

      expect(response.status).to eq(404)
      expect(response.body).not_to include(private_post.user.email)
    end
  end
end
