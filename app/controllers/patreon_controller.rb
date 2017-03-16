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
    filters = PluginStore.get(PLUGIN_NAME, 'filters')

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
    return render json: { message: "Error"}, status: 500 if params[:reward_list] == '' || !is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, 'filters') || {}

    rewards_ids = find_reward_by_name(params[:reward_list])

    filters[params[:group_id]] = rewards_ids

    PluginStore.set(PLUGIN_NAME, 'filters', filters)

    render json: success_json
  end

  def find_reward_by_name name_list

    rewards = PluginStore.get(PLUGIN_NAME, 'rewards')

    rewards.select { |_, v| name_list.split('|').include? v['title'] }.map { |k, _| k }
  end

  def delete
    return render json: { message: "Error"}, status: 500 if params[:channel] == '' || !is_number?(params[:category_id])

    DiscourseSlack::Slack.delete_filter('*', params[:channel]) if ( params[:category_id] === "0" )
    DiscourseSlack::Slack.delete_filter(params[:category_id], params[:channel])

    render json: success_json
  end

  def command
    guardian = Guardian.new(User.find_by_username(SiteSetting.slack_discourse_username))

    tokens = params[:text].split(" ")

    # channel name fix
    if (params[:channel_name] === "directmessage")
      channel = "@#{params[:user_name]}"
    elsif (params[:channel_name] === "privategroup")
      channel = params[:channel_id]
    else
      channel = "##{params[:channel_name]}"
    end

    cmd = "help"

    if tokens.size > 0 && tokens.size < 3
      cmd = tokens[0]
    end
    ## TODO Put back URL finding
    case cmd
    when "watch", "follow", "mute"
      if (tokens.size == 2)
        cat_name = tokens[1]
        category = Category.find_by({slug: cat_name})
        if (cat_name.casecmp("all") === 0)
          DiscourseSlack::Slack.set_filter_by_id('*', channel, cmd, params[:channel_id])
          render json: { text: "*#{DiscourseSlack::Slack.filter_to_past(cmd).capitalize} all categories* on this channel." }
        elsif (category && guardian.can_see_category?(category))
          DiscourseSlack::Slack.set_filter_by_id(category.id, channel, cmd, params[:channel_id])
          render json: { text: "*#{DiscourseSlack::Slack.filter_to_past(cmd).capitalize}* category *#{category.name}*" }
        else
          # TODO DRY (easy)
          cat_list = (CategoryList.new(Guardian.new User.find_by_username(SiteSetting.slack_discourse_username)).categories.map { |c| c.slug }).join(', ')
          render json: { text: "I can't find the *#{tokens[1]}* category. Did you mean: #{cat_list}" }
        end
      else
        render json: { text: DiscourseSlack::Slack.help }
      end
    when "help"
      render json: { text: DiscourseSlack::Slack.help }
    when "status"
      render json: { text: DiscourseSlack::Slack.status, link_names: 1 }
    else
      render json: { text: DiscourseSlack::Slack.help }
    end
  end

  def knock
    route = topic_route params[:text]
    post_number = route[:post_number] ? route[:post_number].to_i : 1

    topic = find_topic(route[:topic_id], post_number)
    post = find_post(topic, post_number)

    render json: DiscourseSlack::Slack.slack_message(post)
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