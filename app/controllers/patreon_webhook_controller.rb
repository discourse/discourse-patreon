# frozen_string_literal: true

require "openssl"
require "json"

class ::Patreon::PatreonWebhookController < ApplicationController
  skip_before_action :redirect_to_login_if_required,
                     :preload_json,
                     :check_xhr,
                     :verify_authenticity_token

  TRIGGERS = %w[
    pledges:create
    pledges:update
    pledges:delete
    members:pledge:create
    members:pledge:update
    members:pledge:delete
  ]

  def index
    raise Discourse::InvalidAccess.new unless is_valid?

    pledge_data = JSON.parse(request.body.read)
    patreon_id = Patreon::Pledge.get_patreon_id(pledge_data)

    if SiteSetting.patreon_verbose_log
      Rails.logger.warn(
        "Patreon verbose log for Webhook:\n  Id = #{patreon_id}\n  Data = #{pledge_data.inspect}",
      )
    end

    case event
    when "pledges:create", "members:pledge:create"
      Patreon::Pledge.create!(pledge_data)
    when "pledges:update", "members:pledge:update"
      Patreon::Pledge.update!(pledge_data)
    when "pledges:delete", "members:pledge:delete"
      Patreon::Pledge.delete!(pledge_data)
    end

    Jobs.enqueue(:sync_patron_groups, patreon_id: patreon_id)

    render body: nil, status: 200
  end

  def event
    request.headers["X-Patreon-Event"]
  end

  def is_valid?
    TRIGGERS.include?(event) && is_valid_signature?
  end

  private

  def is_valid_signature?
    signature = request.headers["X-Patreon-Signature"]
    digest = OpenSSL::Digest.new("MD5")

    signature ==
      OpenSSL::HMAC.hexdigest(digest, SiteSetting.patreon_webhook_secret, request.raw_post)
  end
end
