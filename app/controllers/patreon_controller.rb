require_dependency 'application_controller'
  
class ::Patreon::PatreonController < ::ApplicationController

  PLUGIN_NAME = 'discourse-patreon'.freeze

  requires_plugin PLUGIN_NAME

  # before_filter :slack_enabled?
  # before_filter :slack_discourse_username_present?

  # before_filter :slack_token_valid?, :except => [:list, :edit, :delete, :test_notification, :reset_settings]
  # skip_before_filter :check_xhr, :preload_json, :verify_authenticity_token, except: [:list, :edit, :delete, :test_notification, :reset_settings]

  # before_filter :slack_webhook_or_token_present?

  def slack_enabled?
    raise Discourse::NotFound unless SiteSetting.slack_enabled?
  end

  def list
    filters = (PluginStore.get(PLUGIN_NAME, 'filters') || {})

    render json: filters
  end

  def rewards
    rewards = PluginStore.get(PLUGIN_NAME, 'rewards')

    render json: rewards
  end

  def is_number? string
    true if Float(string) rescue false
  end

  def edit
    return render json: { message: "Error"}, status: 500 if params[:rewards_ids] == '' || !is_number?(params[:group_id])

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

  def slack_token_valid?
    raise Discourse::InvalidAccess.new if SiteSetting.slack_incoming_webhook_token.blank?
    raise Discourse::InvalidAccess.new unless SiteSetting.slack_incoming_webhook_token == params[:token]
  end

  def slack_discourse_username_present?
    raise Discourse::InvalidAccess.new unless SiteSetting.slack_discourse_username
  end

  def slack_webhook_or_token_present?
    raise Discourse::InvalidAccess.new if SiteSetting.slack_outbound_webhook_url.blank? && SiteSetting.slack_access_token.blank?
  end

  def topic_route(text)
    url = text.slice(text.index("<") + 1, text.index(">") -1)
    url.sub! Discourse.base_url, ''
    route = Rails.application.routes.recognize_path(url)
    raise Discourse::NotFound unless route[:controller] == 'topics' && route[:topic_id]
    route
  end

  def find_post(topic, post_number)
    topic.filtered_posts.select { |p| p.post_number == post_number}.first
  end

  def find_topic(topic_id, post_number)
    user = User.find_by_username SiteSetting.slack_discourse_username
    TopicView.new(topic_id, user, { post_number: post_number })
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