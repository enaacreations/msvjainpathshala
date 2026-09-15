-- Analytics 500 (2026-09-11): GET /v1/admin/analytics/engagement-trend returned
-- ERR_INTERNAL because mv_centre_engagement could never be built.
--
-- REFRESH MATERIALIZED VIEW is a security-restricted operation: Postgres cuts
-- search_path down to the system catalog so a refresh cannot be hijacked by a
-- planted relation. Our SQL helpers name their tables unqualified, so under that
-- reduced path homework_completion_rate_for_centres — inlined into
-- mv_centre_engagement's body — failed with:
--
--   ERROR:   relation "homework_submissions" does not exist
--   CONTEXT: SQL function "homework_completion_rate_for_centres" during inlining
--
-- The table was never missing; public simply was not on the path at that moment.
--
-- refreshAnalyticsViews catches the failure and only logger.warn()s it
-- (apps/api-server/src/jobs/derived-data-jobs.ts), so the nightly
-- analytics.refresh_views run reported success while this one view stayed
-- unpopulated — and every read of an unpopulated MV raises "materialized view
-- has not been populated", which surfaces as a 500 on the analytics tab.
--
-- Pinning search_path on each function makes its name resolution independent of
-- whatever path the caller happens to have. pg_temp is deliberately omitted:
-- leaving it off is what stops a temporary relation from shadowing a real table
-- mid-refresh, which is the attack the restricted path exists to prevent.
--
-- Applied to all eight project functions, not only the one that broke. The rest
-- are the same trap already armed: fn_course_progress (CU28) and
-- attendance_percentage (AT5) are the canonical calculators, and the moment
-- anything refreshes a view through them they fail identically.

ALTER FUNCTION public.attendance_percentage(uuid, date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.attendance_percentage_for_centres(uuid[], date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.attendance_rate_by_batch(uuid, date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.fn_course_progress(uuid, uuid, uuid)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.homework_completion_rate(uuid, date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.homework_completion_rate_by_batch(uuid, date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.homework_completion_rate_for_centres(uuid[], date, date)
  SET search_path = pg_catalog, public;--> statement-breakpoint

ALTER FUNCTION public.punya_ledger_is_append_only()
  SET search_path = pg_catalog, public;--> statement-breakpoint

-- mv_centre_engagement has never held data, so this is its first population
-- rather than a maintenance refresh. The non-blocking form of REFRESH cannot be
-- used on an unpopulated view, which is exactly the fallback refreshAnalyticsViews
-- already performs. Do not name that form in this file even in a comment:
-- migrate.mjs decides whether to wrap a migration in a transaction by regexing
-- the raw file text, so the bare word would silently cost this migration its
-- all-or-nothing guarantee.
REFRESH MATERIALIZED VIEW public.mv_centre_engagement;
