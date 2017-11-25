require 'json'

module ::Patreon
  class Api

    def self.campaign_data
      get('/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page[count]=100')
    end

    def self.get(uri)
      limiter_hr = RateLimiter.new(nil, "patreon_api_hr", SiteSetting.max_patreon_api_reqs_per_hr, 1.hour)
      limiter_day = RateLimiter.new(nil, "patreon_api_day", SiteSetting.max_patreon_api_reqs_per_day, 1.day)

      unless limiter_hr.can_perform?
        limiter_hr.performed!
      end

      unless limiter_day.can_perform?
        limiter_day.performed!
      end

      response = Faraday.new(
        url: 'https://api.patreon.com',
        headers: { 'Authorization' => "Bearer #{SiteSetting.patreon_creator_access_token}" }
      ).get(uri)

      limiter_hr.performed!
      limiter_day.performed!

      unless response.status == 200
        Rails.logger.warn("Patreon API returning error for URL: #{uri}.\n\n #{ response.body.presence || '' }")
        return { "error": "Invalid response from Patreon API" }
      end

      JSON.parse response.body
    end

  end
end
