# frozen_string_literal: true

require_dependency 'application_controller'

class ::Patreon::PatreonAdminController < Admin::AdminController

  PLUGIN_NAME = 'discourse-patreon'.freeze

  requires_plugin PLUGIN_NAME

  before_action :patreon_enabled?
  before_action :patreon_tokens_present?

  def patreon_enabled?
    raise Discourse::NotFound unless SiteSetting.patreon_enabled
  end

  def list
    filters = PluginStore.get(PLUGIN_NAME, 'filters') || {}
    plans = Plan.all
    last_sync = ::Patreon.get("last_sync") || {}

    groups = ::Group.all.pluck(:id)

    valid_filters = filters.select { |k| groups.include?(k.to_i) }

    render json: { filters: valid_filters, plans: plans, last_sync_at: last_sync["at"] }
  end

  def plans
    render json: Plan.select(:id, :type, :name, :amount)
  end

  def is_number?(string)
    true if Float(string) rescue false
  end

  def edit
    return render json: { message: "Error" }, status: 500 if params[:plan_ids].nil? || !is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, 'filters') || {}
    filters[params[:group_id]] = params[:plan_ids].map(&:to_i)
    PluginStore.set(PLUGIN_NAME, 'filters', filters)

    render json: success_json
  end

  def delete
    return render json: { message: "Error" }, status: 500 unless is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, 'filters')

    filters.delete(params[:group_id])

    PluginStore.set(PLUGIN_NAME, 'filters', filters)

    render json: success_json
  end

  def sync_groups
    begin
      Patreon::Member.sync_groups
      render json: success_json
    rescue => e
      render json: { message: e.message }, status: 500
    end
  end

  def update_data
    Jobs.enqueue(:patreon_sync_patrons_to_groups)
    render json: success_json
  end

  def email
    user = fetch_user_from_params(include_inactive: true)

    unless user == current_user
      guardian.ensure_can_check_emails!(user)
      StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])
    end

    render json: {
      email: user&.customer&.email
    }
  end

  def patreon_tokens_present?
    raise Discourse::SiteSettingMissing.new("patreon_creator_access_token") if SiteSetting.patreon_creator_access_token.blank?
    raise Discourse::SiteSettingMissing.new("patreon_creator_refresh_token")  if SiteSetting.patreon_creator_refresh_token.blank?
  end
end
