require_dependency 'application_controller'
  
class ::Patreon::PatreonAdminController < Admin::AdminController

  PLUGIN_NAME = 'discourse-patreon'.freeze

  requires_plugin PLUGIN_NAME

  before_filter :patreon_enabled?
  before_filter :patreon_tokens_present?

  def patreon_enabled?
    raise Discourse::NotFound unless SiteSetting.patreon_enabled
  end

  def list
    filters = (PluginStore.get(PLUGIN_NAME, 'filters') || {})

    groups = ::Group.all.pluck(:id)

    valid_filters = filters.select {|k| groups.include?(k.to_i) }

    render json: valid_filters
  end

  def rewards
    rewards = PluginStore.get(PLUGIN_NAME, 'rewards')

    render json: rewards
  end

  def is_number? string
    true if Float(string) rescue false
  end

  def edit
    return render json: { message: "Error"}, status: 500 if params[:rewards_ids].nil? || !is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, 'filters') || {}

    filters[params[:group_id]] = params[:rewards_ids]

    PluginStore.set(PLUGIN_NAME, 'filters', filters)

    render json: success_json
  end

  def delete
    return render json: { message: "Error"}, status: 500 unless is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, 'filters')

    puts filters

    filters.delete(params[:group_id])

    puts filters

    PluginStore.set(PLUGIN_NAME, 'filters', filters)

    render json: success_json
  end

  def patreon_tokens_present?
    raise Discourse::InvalidAccess.new if SiteSetting.patreon_creator_access_token.blank?
    raise Discourse::InvalidAccess.new if SiteSetting.patreon_creator_refresh_token.blank?
  end

  # ----- Access control methods -----
  def handle_unverified_request
  end

  def api_key_valid?
    true
  end

  def redirect_to_login_if_required
  end
end