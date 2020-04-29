# frozen_string_literal: true

require 'json'

module ::Patreon

  class InvalidApiResponse < ::StandardError; end

  class Api

    ACCESS_TOKEN_INVALID = "dashboard.patreon.access_token_invalid".freeze
    INVALID_RESPONSE = "patreon.error.invalid_response".freeze

    def self.get(path, params = nil)
      path = "/oauth2/v2/#{path}"
      limiter_hr = RateLimiter.new(nil, "patreon_api_hr", SiteSetting.max_patreon_api_reqs_per_hr, 1.hour)
      limiter_day = RateLimiter.new(nil, "patreon_api_day", SiteSetting.max_patreon_api_reqs_per_day, 1.day)
      AdminDashboardData.clear_problem_message(ACCESS_TOKEN_INVALID) if AdminDashboardData.problem_message_check(ACCESS_TOKEN_INVALID)

      unless limiter_hr.can_perform?
        limiter_hr.performed!
      end

      unless limiter_day.can_perform?
        limiter_day.performed!
      end

      response = Faraday.new(
        url: 'https://api.patreon.com',
        headers: { 'Authorization' => "Bearer #{SiteSetting.patreon_creator_access_token}" }
      ).get(path, params)

      limiter_hr.performed!
      limiter_day.performed!

      case response.status
      when 200
        return JSON.parse(response.body.presence || {})
      when 401
        AdminDashboardData.add_problem_message(ACCESS_TOKEN_INVALID, 7.hours)
      else
        e = ::Patreon::InvalidApiResponse.new(response.body.presence || '')
        e.set_backtrace(caller)
        Discourse.warn_exception(e, message: I18n.t(INVALID_RESPONSE), env: { api_uri: path })
      end

      { error: I18n.t(INVALID_RESPONSE) }
    end

  end
end
