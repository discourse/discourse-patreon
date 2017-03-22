import FilterRule from 'discourse/plugins/discourse-patreon/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({

  prettyPrintReward: (reward) => {
    return `$${reward.amount_cents/100} - ${reward.title}`;
  },
  
  rewardsNames: function() {
    return _.filter(this.rewards, (r) => r.amount_cents > 1).map((r) => this.prettyPrintReward(r));
  }.property(),

  editing: FilterRule.create({}),

  actions: {
    save() {
      const rule = this.get('editing');
      const model = this.get('model');

      rule.set('group', this.groups.find((x) => x.id === parseInt(rule.get('group_id'))));
      rule.set('rewards_ids', _.filter(this.rewards, (v) => rule.get('reward_list').includes(this.prettyPrintReward(v))).map((r) => r.id));

      ajax("/patreon/list.json", {
        method: 'POST',
        data: rule.getProperties('group_id', 'rewards_ids')
      }).then(() => {
        var obj = model.find((x) => ( x.get('group_id') === rule.get('group_id') ));
        const rewards = rule.get('reward_list').replace(/\|/g, ', ');
        if (obj) {
          obj.set('reward_list', rewards);
          obj.set('rewards', rewards);
          obj.set('rewards_ids', rule.rewards_ids);
        } else {
          model.pushObject(FilterRule.create({group: rule.get('group.name'), rewards: rewards}));
        }
        this.set('editing', FilterRule.create({}));
      }).catch(popupAjaxError);
    },

    delete(rule) {
      const model = this.get('model');

      ajax("/patreon/list.json", { method: 'DELETE',
        data: rule.getProperties('group_id')
      }).then(() => {
        var obj = model.find((x) => ( x.get('group_id') === rule.get('group_id')));
        model.removeObject(obj);
      }).catch(popupAjaxError);
    },

    updateData() {
      this.set('updatingData', true);

      ajax("/patreon/update_data.json", { method: 'POST' })
        .catch(popupAjaxError)
        .finally(() => {
          this.set('updatingData', false);
        });
    },

    syncGroups() {
      this.set('syncingGroups', true);

      ajax("/patreon/sync_groups.json", { method: 'POST' })
        .catch(popupAjaxError)
        .finally(() => {
          this.set('syncingGroups', false);
        });
    }
  }
});
