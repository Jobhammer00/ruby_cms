# frozen_string_literal: true

module RubyCms
  module Admin
    # Reusable card wrapper for admin resource pages (combined show/edit).
    # Provides a two-column layout with form fields on the left and a
    # details sidebar on the right, plus an actions footer.
    #
    # Intended to be wrapped in a form_with tag by the view so the
    # submit button in the actions footer works naturally.
    #
    # Usage:
    #
    #   <%= form_with model: [:admin, @sport], local: true do |form| %>
    #     <div class="<%= RubyCms::Admin::AdminResourceCard::CARD_CLASS %>">
    #       <div class="<%= RubyCms::Admin::AdminResourceCard::GRID_CLASS %>">
    #         <div class="<%= RubyCms::Admin::AdminResourceCard::MAIN_CLASS %>">
    #           form fields...
    #         </div>
    #         <div class="<%= RubyCms::Admin::AdminResourceCard::SIDEBAR_CLASS %>">
    #           details...
    #         </div>
    #       </div>
    #       <div class="<%= RubyCms::Admin::AdminResourceCard::ACTIONS_CLASS %>">
    #         cancel / save
    #       </div>
    #     </div>
    #   <% end %>
    #
    class AdminResourceCard < BaseComponent
      CARD_CLASS = "bg-card shadow-sm rounded-xl border border-border/60 ring-1 ring-black/[0.03] overflow-hidden"
      GRID_CLASS = "grid grid-cols-1 lg:grid-cols-3"
      MAIN_CLASS = "lg:col-span-2 p-6 space-y-6"
      SIDEBAR_CLASS = "border-t lg:border-t-0 lg:border-l border-border/60 bg-muted/20 p-6 space-y-6"
      ACTIONS_CLASS = "flex items-center justify-end gap-3 border-t border-border/60 px-6 py-4 bg-muted/20"

      INPUT_CLASS = "block w-full rounded-lg border border-border bg-background px-3 py-2 text-sm text-foreground shadow-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors"
      LABEL_CLASS = "block text-sm font-medium text-foreground mb-1.5"
      HINT_CLASS = "mt-1 text-xs text-muted-foreground"
      FILE_INPUT_CLASS = "block w-full text-sm text-muted-foreground file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-primary/10 file:text-primary hover:file:bg-primary/20 transition-colors"

      SECTION_CLASS = "rounded-xl border border-border/60 bg-muted/30 p-5"
      SECTION_TITLE_CLASS = "text-sm font-semibold text-foreground tracking-tight mb-4"
      DETAIL_LABEL_CLASS = "text-xs font-medium text-muted-foreground uppercase tracking-wider"
      DETAIL_VALUE_CLASS = "mt-1 text-sm text-foreground"

      CANCEL_CLASS = "inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg border border-border bg-background text-foreground hover:bg-muted transition-colors"
      SUBMIT_CLASS = "inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 shadow-sm transition-colors"

      def view_template(&)
        div(class: CARD_CLASS, &)
      end
    end
  end
end
