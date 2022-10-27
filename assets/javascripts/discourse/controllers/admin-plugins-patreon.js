import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import FilterRule from "discourse/plugins/discourse-patreon/discourse/models/filter-rule";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default Controller.extend({
  dialog: service(),
  prettyPrintReward: (reward) => {
    return `$${reward.amount_cents / 100} - ${reward.title}`;
  },

  @discourseComputed("rewards")
  rewardsNames() {
    return Object.values(this.rewards)
      .filter((r) => r.id >= 0)
      .map((r) => this.prettyPrintReward(r));
  },

  editing: FilterRule.create({ group_id: null }),

  actions: {
    save() {
      const rule = this.get("editing");
      const model = this.get("model");

      rule.set(
        "group",
        this.groups.find((x) => x.id === parseInt(rule.get("group_id"), 10))
      );
      rule.set(
        "rewards_ids",
        Object.values(this.rewards)
          .filter((v) =>
            rule.get("reward_list").includes(this.prettyPrintReward(v))
          )
          .map((r) => r.id)
      );

      ajax("/patreon/list.json", {
        method: "POST",
        data: rule.getProperties("group_id", "rewards_ids"),
      })
        .then(() => {
          let obj = model.find(
            (x) => x.get("group_id") === rule.get("group_id")
          );
          const rewards = rule.get("reward_list").filter(Boolean);
          if (obj) {
            obj.set("reward_list", rewards);
            obj.set("rewards", rewards);
            obj.set("rewards_ids", rule.rewards_ids);
          } else {
            model.pushObject(
              FilterRule.create({
                group: rule.get("group.name"),
                rewards,
              })
            );
          }
          this.set("editing", FilterRule.create({ group_id: null }));
        })
        .catch(popupAjaxError);
    },

    delete(rule) {
      const model = this.get("model");

      ajax("/patreon/list.json", {
        method: "DELETE",
        data: rule.getProperties("group_id"),
      })
        .then(() => {
          let obj = model.find(
            (x) => x.get("group_id") === rule.get("group_id")
          );
          model.removeObject(obj);
        })
        .catch(popupAjaxError);
    },

    updateData() {
      this.set("updatingData", true);

      ajax("/patreon/update_data.json", { method: "POST" })
        .catch(popupAjaxError)
        .finally(() => this.set("updatingData", false));

      this.messageBus.subscribe("/patreon/background_sync", () => {
        this.messageBus.unsubscribe("/patreon/background_sync");

        this.set("updatingData", false);

        const refreshUrl = getURL("/admin/plugins/patreon");
        this.dialog.alert({
          message: I18n.t("patreon.refresh_page"),
          didConfirm: () => (window.location.pathname = refreshUrl),
          didCancel: () => (window.location.pathname = refreshUrl),
        });
      });
    },
  },
});
