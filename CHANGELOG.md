## [Unreleased]

## [0.2.0.8] - 2026-04-09

- Analytics performance: migration adds `ahoy_events (name, time)`, `ahoy_events (visit_id, time)`, `ahoy_visits (started_at)`, `ahoy_visits (visitor_token)` indexes
- Analytics performance: `compute_new_visitor_percentage` uses subquery instead of plucking all historical visitor tokens into Ruby memory
- Analytics performance: `exit_pages_data` uses a single DB join-subquery instead of loading all page view rows into Ruby

## [0.2.0.7] - 2026-04-09

- Analytics: add `EVENT_PAGE_VIEW` / `EVENT_CONVERSION` constants for consistent ahoy.track usage
- Analytics: conversion tracking — `Report` queries `conversion` events and surfaces totals + goal breakdown in dashboard
- Analytics: exit pages — last `page_view` per visit in selected range, displayed as new dashboard section
- Analytics: period-over-period comparison — KPI deltas (↑/↓ %) shown on page views, unique visitors, and sessions stat cards
- Analytics: expanded bot-filtering documentation in install template (`analytics_visit_scope` examples)
- Analytics: register `analytics_max_exit_pages`, `analytics_max_conversions`, `analytics_max_referrers`, `analytics_max_landing_pages`, `analytics_max_utm_sources` in SettingsRegistry
- PageTracking: document conversion tracking convention in concern comments
- Locales: add analytics i18n keys for exit pages, conversions, and period comparison (en + nl)

## [0.2.0.6] - 2026-04-09

- Analytics improvements

## [0.2.0.5] - 2026-04-08

- The host app no longer needs to scan de gem for tailwind

## [0.2.0.3] - 2026-04-02

- Whole repo was scanned for comiling so it was slow.

## [0.2.0.2] - 2026-04-02

- Add commands page

## [0.2.0.1] - 2026-04-02

- Fix compile


## [0.2.0] - 2026-04-02

- Update add page generator, dashboard blocks and some ui tweaks.

## [0.1.0.9] - 2026-03-25

- Update gems

## [0.1.0.8] - 2026-03-25

- Update admin page styling

## [0.1.0.7] - 2026-03-25

- Improve some styling and fix rich text

## [0.1.0.6] - 2026-03-23

- Fix visual editor content block bug

## [0.1.5] - 2026-03-23

- Fix image bug

## [0.1.4] - 2026-03-23

- Improve visual editor and settings admin UX
- Update sidebar branding to use the new RubyCMS logo
- Refresh README with project logo

## [0.1.3] - 2026-03-23

- Update analytics pages (dashboard/detail views)
- Update admin settings UI (including bulk action table)

## [0.1.2] - 2026-03-23

- Update settings page and the bulk action table
- Combined the permissions

## [0.1.1] - 2026-03-18

- Fix admin templates calling `AdminPage(...)` instead of the `admin_page` helper

## [0.1.0] - 2026-01-25

- Initial release
