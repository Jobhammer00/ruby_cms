import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["commandOutput", "appLog"];
  static values = { runUrl: String };

  async run(event) {
    const key =
      event.currentTarget?.dataset?.commandKey || event.params?.key;
    const runUrl = this.runUrlValue?.trim?.() || this.runUrlValue;

    if (!key || !runUrl) {
      const msg =
        !runUrl
          ? "Missing run URL (check data-ruby-cms--admin-commands-run-url-value)."
          : "Missing command key on the button.";
      if (this.hasCommandOutputTarget) {
        this.commandOutputTarget.textContent = msg;
      } else {
        console.error("[ruby-cms--admin-commands]", msg);
      }
      return;
    }

    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    const button = event.currentTarget;
    button.disabled = true;

    if (this.hasCommandOutputTarget) {
      this.commandOutputTarget.textContent = "Running…";
    }
    if (this.hasAppLogTarget) {
      this.appLogTarget.textContent = "…";
    }

    try {
      const response = await fetch(runUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": token || "",
        },
        body: JSON.stringify({ key }),
      });

      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        const err = data.error || `Request failed (${response.status})`;
        if (this.hasCommandOutputTarget) {
          this.commandOutputTarget.textContent = err;
        }
        return;
      }

      if (this.hasCommandOutputTarget) {
        this.commandOutputTarget.textContent =
          data.command_output || "(no output)";
      }
      if (this.hasAppLogTarget) {
        this.appLogTarget.textContent = data.app_log_tail || "(no log lines)";
      }
    } catch (e) {
      if (this.hasCommandOutputTarget) {
        this.commandOutputTarget.textContent = e?.message || String(e);
      }
    } finally {
      button.disabled = false;
    }
  }
}
