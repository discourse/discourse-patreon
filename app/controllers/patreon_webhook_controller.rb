# frozen_string_literal: true

require 'openssl'
require 'json'

class ::Patreon::PatreonWebhookController < ApplicationController

  skip_before_action :redirect_to_login_if_required, :preload_json, :check_xhr, :verify_authenticity_token

  TRIGGERS = ['members:pledge:create', 'members:pledge:update', 'members:pledge:delete']

  def index
    raise Discourse::InvalidAccess.new unless is_valid?

    json = JSON.parse(request.body.read)
    patreon_id = Patreon::Member.get_patreon_id(json["data"])
    campaign_external_id = Patreon::Campaign.find_external_id(json["data"])
    campaign_id = Patreon::Campaign.where(external_id: campaign_external_id).select(:id).first&.id

    if SiteSetting.patreon_verbose_log
      Rails.logger.warn("Patreon verbose log for Webhook:\n  Id = #{patreon_id}\n  Data = #{json.inspect}")
    end

    case event
    when 'members:pledge:create', 'members:pledge:update', 'members:pledge:delete'
      Patreon.update(json, campaign_id)
    end

    Jobs.enqueue(:sync_patron_groups, patreon_id: patreon_id)

    render body: nil, status: 200
  end

  def event
    request.headers['X-Patreon-Event']
  end

  def is_valid?
    TRIGGERS.include?(event) && is_valid_signature?
  end

  private

  def is_valid_signature?
    signature = request.headers['X-Patreon-Signature']
    digest = OpenSSL::Digest::MD5.new

    signature == OpenSSL::HMAC.hexdigest(digest, SiteSetting.patreon_webhook_secret, request.raw_post)
  end
end
