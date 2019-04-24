import { withPluginApi } from "discourse/lib/plugin-api";
import TopicRoute from "discourse/routes/topic";

let numTopicsOpened = 0;

function initWithApi(api) {
  const currentUser = api.getCurrentUser();

  TopicRoute.reopen({
    setupController(controller, model) {
      this._super(controller, model);

      if (!currentUser) return;

      Ember.run.scheduleOnce("afterRender", () => {
        // only count regular topics
        if (model.get("isPrivateMessage")) return;

        if (numTopicsOpened <= this.siteSettings.patreon_donation_prompt_show_after_topics) numTopicsOpened++;
      });
    }
  });

  api.registerConnectorClass("topic-above-footer-buttons", "patreon", {
    shouldRender(args, component) {
      return component.currentUser;
    },

    setupComponent(args, component) {
      component.didInsertElement = function() {
        const showDonationPrompt = (
          this.siteSettings.patreon_enabled &&
          this.siteSettings.patreon_donation_prompt_enabled &&
          this.currentUser.show_donation_prompt &&
          $.cookie("donationPromptClosed") !== "t" &&
          numTopicsOpened > this.siteSettings.patreon_donation_prompt_show_after_topics
        );

        this.set("showDonationPrompt", showDonationPrompt);
      };
    },

    actions: {
      close() {
        const expires = moment().add(30, "d").toDate();
        $.cookie("donationPromptClosed", "t", { expires });
        this.$().fadeOut(700);
      }
    }
  });
}

export default {
  name: "patreon",
  initialize() { withPluginApi("0.8", initWithApi); }
}
