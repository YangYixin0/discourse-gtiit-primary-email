# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  fab!(:viewer) { Fabricate(:user, trust_level: 2) }
  fab!(:author) { Fabricate(:user, trust_level: 2) }

  before { SiteSetting.gtiit_primary_email_enabled = true }

  describe "#show" do
    it "includes the field for a member session" do
      sign_in(viewer)

      get "/u/#{author.username}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("user", "gtiit_primary_email")).to eq(author.email)
    end

    it "omits the field for anonymous requests even on a public forum" do
      SiteSetting.login_required = false

      get "/u/#{author.username}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("user")).not_to have_key("gtiit_primary_email")
      expect(response.body).not_to include(author.email)
    end

    it "omits the field for a valid API key" do
      api_key = Fabricate(:api_key, user: viewer)

      get "/u/#{author.username}.json", headers: { "Api-Key" => api_key.key }

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("user")).not_to have_key("gtiit_primary_email")
      expect(response.body).not_to include(author.email)
    end

    it "omits the field for a valid read-scoped user API key" do
      client = Fabricate(:user_api_key_client, scopes: ["read"])
      key = Fabricate(:user_api_key, user: viewer, client: client)

      get "/u/#{author.username}.json", headers: { "User-Api-Key" => key.key }

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("user")).not_to have_key("gtiit_primary_email")
    end

    it "rejects an invalid API key" do
      get "/u/#{author.username}.json", headers: { "Api-Key" => "invalid" }

      expect(response.status).to eq(403)
      expect(response.body).not_to include(author.email)
    end
  end

  describe "#show_card" do
    it "exposes the primary email to a member on the user card" do
      sign_in(viewer)

      get "/u/#{author.username}/card.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("user", "gtiit_primary_email")).to eq(author.email)
    end
  end

end
