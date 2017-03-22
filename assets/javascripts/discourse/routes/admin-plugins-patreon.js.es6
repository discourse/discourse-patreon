import { ajax } from 'discourse/lib/ajax';
import FilterRule from 'discourse/plugins/discourse-patreon/discourse/models/filter-rule';

/* We use three main model to get this page working:
*  Discourse Groups (excluding the automatic ones), Patreon rewards and
*  and current filters (one filter is a tuple between 1 Discourse group and N Patreon rewards)
*/
export default Discourse.Route.extend({
  model() {

    return Ember.RSVP.Promise.all([ajax("/patreon/list.json"), ajax("/patreon/rewards.json"), ajax("/admin/groups.json")])
                              .then(([filtersResult, rewardsResult, groupsResult]) => {
                                return {filters: filtersResult, rewards: rewardsResult, groups: groupsResult};
                              });
  },

  setupController: function(controller, model) {

    const filtersArray = _.map(model.filters, (v, k) => {
      const rewardsNames = v.map((r) => ` $${model.rewards[r].amount_cents/100} - ${model.rewards[r].title}`);
      const group =_.find(model.groups, (g) => g.id === parseInt(k));

      return FilterRule.create({group: group.name, rewards: rewardsNames, group_id: k, reward_ids: v});
    });

    const automaticGroups = model.groups.reject((g) => g.automatic);

    controller.setProperties({ model: filtersArray, groups: automaticGroups, rewards: model.rewards });
  }
});
