import FilterRule from 'discourse/plugins/discourse-patreon/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  
  groups: function() {
    return this.model.groups.filter((g) => g.automatic === false);
  }.property(),

  rewards_names: function() {
    return _.map(this.model.rewards, (r) => r.title).filter((r) => r !== undefined);
  }.property(),

  filters: function() {
    const model = this.get('model');

    return _.map(model.filters, (v, k) => {
      const rewards_names = v.map((r) => ` ${model.rewards[r].title} (${model.rewards[r].patron_count} patrons)`);
      const group =_.find(model.groups, (g) => g.id === parseInt(k));

      return {group: group.name, rewards: rewards_names};
    });

  }.property(),

  editing: FilterRule.create(this.model),

  actions: {
    save() {
      const rule = this.get('editing');
      const model = this.get('model');

      ajax("/patreon/list.json", {
        method: 'POST',
        data: rule.getProperties('group_id', 'reward_list')
      }).then(() => {
        var obj = model.find((x) => ( x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        if (obj) {
          obj.set('channel', rule.channel);
          obj.set('filter', rule.filter);
        } else {
          model.pushObject(FilterRule.create(rule.getProperties('filter', 'category_id', 'channel')));
        }
      }).catch(popupAjaxError);
    },

    delete(rule) {
      const model = this.get('model');

      ajax("/slack/list.json", { method: 'DELETE',
        data: rule.getProperties('filter', 'category_id', 'channel')
      }).then(() => {
        var obj = model.find((x) => ( x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        model.removeObject(obj);
      }).catch(popupAjaxError);
    }
  }
});
