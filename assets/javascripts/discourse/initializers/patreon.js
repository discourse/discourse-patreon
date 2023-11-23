import { withPluginApi } from "discourse/lib/plugin-api";

let numTopicsOpened = 0;
const cookieName = "PatreonDonationPromptClosed";

function initWithApi(api) {
  const currentUser = api.getCurrentUser();

  api.onAppEvent("page:topic-loaded", (topic) => {
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
}

export default {
  name: "patreon",
  initialize() {
    withPluginApi("0.8", initWithApi);
  },
};
