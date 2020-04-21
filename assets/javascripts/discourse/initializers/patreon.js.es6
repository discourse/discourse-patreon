import { withPluginApi } from "discourse/lib/plugin-api";

let numTopicsOpened = 0;
const cookieName = "PatreonDonationPromptClosed";

function initWithApi(api) {
  const currentUser = api.getCurrentUser();

  api.onAppEvent("page:topic-loaded", topic => {
    if (!topic) {
      return;
    }

    const isPrivateMessage = topic.isPrivateMessage;

    if (!currentUser || isPrivateMessage) {
      return;
    }

    if (
      numTopicsOpened <=
      topic.siteSettings.patreon_donation_prompt_show_after_topics
    ) {
      numTopicsOpened++;
    }
  });

  api.registerConnectorClass("topic-above-footer-buttons", "patreon", {
    shouldRender(_args, component) {
      return component.currentUser;
    },

    setupComponent(_args, component) {
      component.didInsertElement = function() {
        const showDonationPrompt =
          this.siteSettings.patreon_enabled &&
          this.siteSettings.patreon_donation_prompt_enabled &&
          this.siteSettings.patreon_donation_prompt_campaign_url !== "" &&
          this.currentUser.show_donation_prompt &&
          $.cookie(cookieName) !== "t" &&
          numTopicsOpened >
            this.siteSettings.patreon_donation_prompt_show_after_topics;

        this.set("showDonationPrompt", showDonationPrompt);
      };
    },

    actions: {
      close() {
        // hide the donation prompt for 30 days
        const expires = moment()
          .add(30, "d")
          .toDate();
        $.cookie(cookieName, "t", { expires });

        this.$().fadeOut(700);
      }
    }
  });
}

export default {
  name: "patreon",
  initialize() {
    withPluginApi("0.8", initWithApi);
  }
};
