import Group from "discourse/models/group";
import { ajax } from "discourse/lib/ajax";
import FilterRule from "discourse/plugins/discourse-patreon/discourse/models/filter-rule";
import DiscourseRoute from "discourse/routes/discourse";

/* We use three main model to get this page working:
 *  Discourse Groups (excluding the automatic ones), Patreon rewards and
 *  and current filters (one filter is a tuple between 1 Discourse group and N Patreon rewards)
 */
export default DiscourseRoute.extend({
  model() {
    return Ember.RSVP.Promise.all([
      ajax("/patreon/list.json"),
      Group.findAll({ ignore_automatic: true }),
    ]).then(([result, groups]) => {
      groups = groups.map((g) => {
        return { id: g.id, name: g.name };
      });

      return {
        filters: result.filters,
        rewards: result.rewards,
        last_sync_at: result.last_sync_at,
        groups: groups,
      };
    });
  },

  setupController: function (controller, model) {
    const rewards = model.rewards;
    const groups = model.groups;
    const filtersArray = _.map(model.filters, (v, k) => {
      const rewardsNames = v.map((r) =>
        rewards[r]
          ? ` $${rewards[r].amount_cents / 100} - ${rewards[r].title}`
          : ""
      );
      const group = _.find(groups, (g) => g.id === parseInt(k, 10));

      return FilterRule.create({
        group: group.name,
        rewards: rewardsNames,
        group_id: k,
        reward_ids: v,
      });
    });

    controller.setProperties({
      model: filtersArray,
      groups: groups,
      rewards: rewards,
      last_sync_at: model.last_sync_at,
    });
  },
});
