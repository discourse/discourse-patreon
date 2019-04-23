import { withPluginApi } from "discourse/lib/plugin-api";
import TopicRoute from "discourse/routes/topic";

let numTopicsOpened = 0;
let donationPromptClosed = false;

function initWithApi(api) {
  TopicRoute.reopen({
    setupController(controller, model) {
      this._super(controller, model);

      Ember.run.scheduleOnce("afterRender", () => {
        // only count regular topics
        if (model.get("isPrivateMessage")) return;

        if (numTopicsOpened <= this.siteSettings.patreon_donation_prompt_show_after_topics) numTopicsOpened++;
      });
    }
  });

  api.registerConnectorClass("topic-above-suggested", "patreon", {
    setupComponent(args, component) {
      component.didInsertElement = function() {
        const showDonationPrompt = (
          this.siteSettings.patreon_enabled &&
          this.siteSettings.patreon_donation_prompt_enabled &&
          (!this.currentUser || this.currentUser.show_donation_prompt) &&
          !donationPromptClosed &&
          numTopicsOpened > this.siteSettings.patreon_donation_prompt_show_after_topics
        );

        this.set("showDonationPrompt", showDonationPrompt);
      };
    },

    actions: {
      close() {
        donationPromptClosed = true;
        this.$().fadeOut(700);
      }
    }
  });
}

export default {
  name: "patreon",
  initialize() { withPluginApi("0.8", initWithApi); }
}
