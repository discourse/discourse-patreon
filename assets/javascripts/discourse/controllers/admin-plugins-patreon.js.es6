import { default as computed } from "ember-addons/ember-computed-decorators";
import FilterRule from "discourse/plugins/discourse-patreon/discourse/models/filter-rule";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  @computed("plans")
  choices() {
    return this.plans.map(p => {
      name = `$${p.amount} - ${p.name}`;
      return { id: p.id, name };
    });
  },

  editing: FilterRule.create({ group_id: null }),

  actions: {
    save() {
      const rule = this.get("editing");
      const model = this.get("model");

      rule.set(
        "group",
        this.groups.find(x => x.id === parseInt(rule.get("group_id"), 10))
      );

      ajax("/patreon/list.json", {
        method: "POST",
        data: rule.getProperties("group_id", "plan_ids")
      })
        .then(() => {
          const group = this.groups.find(
            x => x.id === parseInt(rule.get("group_id"), 10)
          );
          const planNames = this.plans
            .filter(p => rule.plan_ids.includes(p.id))
            .map(p => `$${p.amount} - ${p.name}`)
            .join(", ");
          const obj = model.find(x => x.group === group.name);

          if (obj) {
            obj.set("plans", planNames);
          } else {
            model.pushObject(
              FilterRule.create({
                group: group.name,
                plans: planNames
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
        data: rule.getProperties("group_id")
      })
        .then(() => {
          var obj = model.find(x => x.get("group_id") === rule.get("group_id"));
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

        bootbox.alert(I18n.t("patreon.refresh_page"), () => {
          window.location.pathname = Discourse.getURL("/admin/plugins/patreon");
        });
      });
    }
  }
});
