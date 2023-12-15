import cookie from "discourse/lib/cookie";

let numTopicsOpened = 0;
const cookieName = "PatreonDonationPromptClosed";

export function incrementTopicsOpened() {
  numTopicsOpened++;
}

export default {
  shouldRender(_args, component) {
    return component.currentUser;
  },

  setupComponent(_args, component) {
    component.didInsertElement = function () {
      const showDonationPrompt =
        this.siteSettings.patreon_enabled &&
        this.siteSettings.patreon_donation_prompt_enabled &&
        this.siteSettings.patreon_donation_prompt_campaign_url !== "" &&
        this.currentUser.show_donation_prompt &&
        cookie(cookieName) !== "t" &&
        numTopicsOpened >
          this.siteSettings.patreon_donation_prompt_show_after_topics;

      this.set("showDonationPrompt", showDonationPrompt);
    };
  },

  actions: {
    close() {
      // hide the donation prompt for 30 days
      const expires = moment().add(30, "d").toDate();
      cookie(cookieName, "t", { expires });

      $(this.element).fadeOut(700);
    },
  },
};
