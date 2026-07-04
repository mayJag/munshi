# Money Tracker — Implementation Plan
**For review before any code is written.**
Source spec: `moneytrackerappplan.md` (build brief). This plan makes every open decision in the brief concrete and lists exactly what will be built, with what, in what order.

---

## 1. Stack Decision (and why)

**Flutter + Dart, Android-only APK.**

Rationale — not just preference, but proven on this machine:
- The Flutter SDK (3.44.4), Android SDK, Gradle toolchain, and release-APK pipeline are **already installed and battle-tested here** (six ChronoRep releases built with it). Zero environment risk.
- Flutter has first-class libraries for every hard requirement in the brief (see §2) — including the one genuinely hard requirement, **Excel export with embedded native charts**, which React Native has no good answer for without a JS bridge to `exceljs` (charts unsupported) or a Python sidecar (impossible on-device).
- Kotlin/Compose would work but means hand-rolling chart + Excel layers; slower to a polished result.

**Explicitly rejected:** React Native (weak Excel-chart story), native Kotlin (slower to polish), any Python helper (can't run on-device).

---

## 2. Packages / Plugins (the "skills and tools" list)

| Concern | Package | Version | Why this one |
|---|---|---|---|
| Local relational DB | **`drift`** (+ `drift_dev`, `build_runner`) | 2.34 | Type-safe reactive SQLite. The data model (6+ related tables, aggregations for charts/budgets) genuinely needs SQL + streams. Reactive queries = UI auto-updates when a transaction is logged. |
| In-app charts | **`fl_chart`** | 1.2 | Pie/donut, bar, line — all needed chart types, highly customizable so the app doesn't look "template". Already suggested by the brief. |
| Excel export **with embedded charts** | **`syncfusion_flutter_xlsio`** + `syncfusion_officechart` | 33.2 | The only Dart library that writes **native, editable chart objects** into `.xlsx` (pie, bar, line), plus styled headers, frozen rows, number formats, autofit. Free under Syncfusion Community License (individual developer / small revenue — applies here). Fallback if licensing ever becomes a problem: `excel` package (data + styling, no charts) — noted as risk in §8. |
| Local notifications | **`flutter_local_notifications`** | 22.0 | Scheduled + repeating (hourly/daily/custom weekly), survives reboot via boot receiver, supports notification actions (Snooze button), full-screen deep-link intent into quick-add. |
| Exact-schedule backup | **`android_alarm_manager_plus`** | latest | Only if `flutter_local_notifications`' inexact repeating proves unreliable for "every N hours" on modern Android (Doze). Spike in Phase 0 decides whether it's needed. |
| Share/save exported file | **`share_plus`** + **`path_provider`** | latest | Share sheet for the `.xlsx` (email, Drive, WhatsApp) and app-documents storage. |
| CSV import | **`file_picker`** + **`csv`** | latest | Pick a CSV (manually exported bank statement), parse, map columns, bulk-insert. |
| Animations/polish | **`flutter_animate`** + **`google_fonts`** | latest | Same polish toolkit used in ChronoRep — staggered entrances, shimmer, spring transitions. |
| Deep links from notification | `flutter_local_notifications` payload + app-level route handling | — | Notification tap → quick-add screen directly. |
| Prefs (theme, settings) | **`shared_preferences`** | latest | Small key-value settings only; all financial data lives in drift/SQLite. |

**No backend, no auth service, no cloud** in v1 — offline-first per the brief. Optional PIN/biometric lock deferred to Phase 6 (uses `local_auth` if added).

**Claude Code skills used during the build:** none beyond core tools — this is a from-scratch Flutter build (Write/Edit/Bash + `flutter analyze`/`build apk`), same workflow as ChronoRep. No MCP plugins required.

---

## 3. Design Direction

- **Identity:** professional fintech dark theme — near-black neutral surfaces, a single confident accent (deep teal/green family — money-coded, distinct from ChronoRep's crimson), high-contrast typography (Inter), generous whitespace, soft depth. No neon, no template look.
- **Signature interactions:**
  - **2-tap quick add** as the centerpiece: FAB → numeric keypad sheet with amount pre-focused → tap category chip → saved (haptic tick + subtle confetti on streaks). Date defaults to today; note/account are one optional tap deeper.
  - **"Safe to spend today"** hero number on the dashboard, PocketGuard-style, animated count-up.
  - Animated splash screen (brand mark), staggered list entrances, smooth chart animations.
- Every list/chart gets a designed empty state; loading states shimmer.

---

## 4. Data Model (drift tables — final)

Follows the brief's sketch with concrete types and a few corrections:

```
accounts            id, name, type(cash|bank|card|wallet), openingBalance, icon, color, isArchived
categories          id, name, parentId?, icon, color, isCustom, sortOrder
budgets             id, monthKey("2026-07"), categoryId, allocatedMinor(int, paise), rolloverEnabled
transactions        id, dateTime, amountMinor(int), type(expense|income|transfer),
                    categoryId?, accountId, transferToAccountId?, note?,
                    recurringTemplateId?, createdAt
recurring_templates id, name, amountMinor, categoryId, accountId, frequency(monthly|weekly|custom),
                    nextDueDate, isActive
reminders           id, type(hourly|daily|custom), intervalHours?, timesOfDay(json)?,
                    daysOfWeek(json)?, message, isActive
investment_snapshots id, date, instrumentName, valueMinor        (Phase 6, optional)
```

Key decisions:
- **All money stored as integer minor units (paise)** — no float currency bugs. Display layer formats ₹.
- Account **running balance is computed** (openingBalance + Σ transactions), never stored — eliminates drift/corruption bugs from the brief's "manually updated balance".
- Transfers are one transaction row with `transferToAccountId`, excluded from category/spend aggregates by `type`.
- Budget month keyed as `"YYYY-MM"` string; rollover computed at month boundary, not stored.

---

## 5. Screens (12)

1. **Splash** — animated brand mark → dashboard.
2. **Dashboard** — safe-to-spend hero, month spend vs budget summary ring, per-category mini bars, recent transactions, quick-add FAB.
3. **Quick Add sheet** — the 2-tap flow (amount keypad → category grid). Also reachable via notification deep-link.
4. **Transactions** — infinite list grouped by day, search + filters (account/category/type/date range), swipe to edit/delete/duplicate.
5. **Transaction editor** — full form (all fields), also handles transfer entry.
6. **Budgets** — month picker, per-category allocation editor, budget-vs-actual bars, rollover toggle, life-stage starter templates (student / professional / family).
7. **Analytics** — donut (category share, tap slice → drill-down), budget-vs-actual bars, trend line (W/M/Y), day-of-week heatmap, month-over-month comparison, top-3 overspend drivers.
8. **Accounts** — cards per account with computed balances + consolidated net; add/edit/archive; transfer shortcut.
9. **Recurring** — template list, "log now" one-tap, next-due badges.
10. **Reminders** — list of schedules; add/edit sheet (hourly every-N / daily at time / custom times+days); active toggles.
11. **Export** — date-range picker, preview of what's included, generate `.xlsx` → share sheet. (3 sheets: transactions log, category pivot summary, account summary; embedded pie + bar + line charts.)
12. **Settings** — currency symbol, first day of week, category manager (add/edit/reorder/merge), CSV import wizard, about.

---

## 6. Build Phases (mirrors the brief, adapted)

**Phase 0 — Setup + risk spikes (first, non-negotiable)**
- Scaffold project (`com.jagga.moneytracker`), add all packages, confirm release APK builds.
- **Spike 1:** generate an `.xlsx` with one embedded pie chart via syncfusion_xlsio, open it in Excel/Sheets — proves the hardest requirement before anything is built on it.
- **Spike 2:** schedule an hourly repeating notification + a daily-at-time one; verify fire + reboot survival + deep-link payload.
- Deliverable: "walking skeleton" APK with nav shell + both spikes passing.

**Phase 1 — Data core + entry loop**
- Drift schema + DAOs + seed (predefined categories, default Cash account).
- Accounts CRUD, quick-add flow, transactions list + editor, transfers.
- Deliverable: usable expense logger APK.

**Phase 2 — Budgets**
- Budget setup per category/month, rollover, budget-vs-actual live view, life-stage templates.

**Phase 3 — Analytics + dashboard**
- All fl_chart visuals, safe-to-spend computation (budget − spent − upcoming recurring), drill-downs, heatmap, MoM comparison.

**Phase 4 — Recurring + alerts + reminders**
- Recurring templates + one-tap log + next-due; overspend local alerts at 80%/100% (checked on each transaction insert); full reminder scheduler UI + snooze.

**Phase 5 — Excel export + CSV import**
- 3-sheet styled workbook with embedded charts, share sheet; CSV import wizard with column mapping + duplicate detection.

**Phase 6 — Polish & optional**
- Empty/edge states pass, performance pass, investment ledger (manual snapshots + trend), astrology-calendar fun flag (off by default), PIN/biometric lock — only as time/interest allows.

Each phase ends with `flutter analyze` clean + a buildable APK, released to GitHub the same way as ChronoRep (versioned releases with attached APK) if you want it on the repo — **or kept local until you say publish; default: local until Phase 1 is done, then I'll ask.**

---

## 7. Project Location & Delivery

- New standalone project at `C:\Users\jagga\money_tracker\` (this folder — plan lives here too).
- Fresh git repo; GitHub repo creation **only with your OK** (name suggestion: `PaisaTrack` / `MoneyTracker` — your call).
- Deliverable per milestone: installable release `.apk` (sideload, same flow you've used for ChronoRep).

## 8. Risks & Honest Notes

| Risk | Mitigation |
|---|---|
| Syncfusion license: free Community License requires <$1M revenue & ≤5 devs — fine for personal use, but it's a commercial vendor | Confirmed acceptable for personal builds; fallback is `excel` package (loses embedded charts → would ship chart images instead). Spike in Phase 0 validates before dependence. |
| Exact hourly notifications vs Android Doze/battery optimizers | Use inexact repeating first (fires within a window); escalate to `android_alarm_manager_plus` + exact-alarm permission only if spike shows unacceptable drift. OEM battery killers (Xiaomi etc.) can still suppress — will document the "allow background" toggle in-app. |
| Scope: the brief is 6 phases of real product | Phases are strictly ordered; each ends in a working APK, so you can stop/redirect at any milestone. |
| CSV import formats vary wildly by bank | V1 ships a generic column-mapping wizard (date/amount/note columns user-picked), not per-bank parsers. |

## 9. What I need from you before starting

1. **Approve this plan** (or mark up changes — stack, accent color, screen list, phase order, anything).
2. **App name** — working name for the APK/launcher (e.g., "PaisaTrack", "Khaata", "SpendWise" — or yours).
3. **GitHub**: new repo from the start, or local-only until Phase 1 is working?
