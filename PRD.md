# SubTrack — Product Requirements Document (PRD)

> Living doc. The plan (`SubTrack-MVP-Plan.md`) is the source of truth. If this PRD and the plan disagree, **the plan wins** — fix the PRD.
> Platform: iOS only. Swift + SwiftUI. Xcode. Min iOS 18. Worldwide. 4 weeks, solo. No Android/web/Flutter/RN/backend/hiring.

**How to read this doc (short):** Answer first, details after. Plain English. Each new term is explained once. Real choices are shown as **FAST / BALANCED / AMBITIOUS**. Steps are numbered.

---

## 1. Problem & Differentiator

People lose money on subscriptions and bills they forget about, and they get hit by failed charges when the wallet or card behind a renewal runs low. **SubTrack** is a local-only iOS app (no login, no cloud) that tracks recurring subscriptions and bills, and its differentiator is that it tracks **which payment method** (e-wallet, bank, card) each subscription is charged to and **warns you before a renewal when that wallet's balance may be too low** — something generic subscription trackers do not do.

---

## 2. In-Scope / Out-of-Scope

### 2.1 LOCKED DECISIONS (verbatim from plan)

> LOCKED DECISIONS: Storage=SwiftData (local only, no CloudKit MVP). Min iOS=18. Monetization=RevenueCat monthly sub, free tier limited to 5 subscriptions. Payment method input=free text + autocomplete (no fixed list). Balance warning IN MVP (manual balance entry). Currency=single picker in Settings (no FX). Backend=none.

### 2.2 OUT OF MVP — do not build (verbatim from plan)

> OUT OF MVP (do not build): iCloud/CloudKit sync, bank/e-wallet API, multi-currency conversion, accounts/login, iPad layout, Live Activities, custom dark mode theming (system dark only).

---

## 3. User Stories

Each story is small and testable. **Acceptance criteria are written as a QA gate** (pass/fail).

### US-1 — Add a subscription
As a user, I want to add a subscription so it is tracked.
- **QA gate:** Tapping "+" opens the Add sheet. With a valid name + price entered, **Save** enables; tapping Save closes the sheet and the new row appears in the Home list. Force-quit and reopen → the row is still there.

### US-2 — See my totals
As a user, I want to see my monthly and yearly spend at a glance.
- **QA gate:** Home header shows a monthly total and a yearly total in the currency chosen in Settings. Adding/removing a sub updates both totals immediately.

### US-3 — Know what's due next
As a user, I want subs sorted by when they bill next.
- **QA gate:** Home list is sorted by `nextBillDate` ascending. Each row shows category icon, name, price, payment method name, and "in X days". A sub billed today shows "in 0 days" (or "Today").

### US-4 — Delete a subscription
As a user, I want to remove a sub I no longer have.
- **QA gate:** Swipe left on a Home row reveals Delete; deleting removes the row, updates totals, and it does not return after force-quit/reopen.

### US-5 — Edit a subscription
As a user, I want to change a sub's details.
- **QA gate:** Tapping a row opens the Add/Edit sheet pre-filled with that sub's values. Saving persists edits; totals and next-bill sorting update.

### US-6 — Empty state
As a new user, I want guidance when I have nothing yet.
- **QA gate:** With zero subs, Home shows an empty state with an "Add your first subscription" CTA that opens the Add sheet. Insights shows its own empty state.

### US-7 — Track which payment method pays each sub
As a user, I want each sub tied to a wallet/bank/card.
- **QA gate:** Typing a new payment method name in the Add sheet auto-creates a `PaymentMethod`. Typing "dana" then "Dana" does NOT create two records (case-insensitive, trimmed match). Existing names appear as autocomplete suggestions.

### US-8 — Low-balance warning
As a user, I want to be warned before a renewal if a wallet may be too low.
- **QA gate:** For a payment method with `trackBalance == true`, if the sum of prices of its subs billing in the **next 7 days** > its `balance`, Home shows an AT-RISK warning banner. If `balanceUpdatedAt` is older than 14 days, the banner instead says "balance may be out of date" (no hard warning).

### US-9 — Insights
As a user, I want to see where my money goes.
- **QA gate:** Insights shows a pie chart of spend by category, a pie chart of spend by payment method, and a list of the top 5 most expensive subs by monthly cost. Charts update after add/edit/delete.

### US-10 — Settings
As a user, I want to control currency, reminders, and payment methods.
- **QA gate:** Settings lets me pick one app-wide currency, pick the reminder hour, manage payment methods (list, edit name, edit balance, toggle trackBalance), open the paywall, tap Restore Purchases, open the privacy policy, and view app version.

### US-11 — Renewal reminders
As a user, I want a heads-up before a charge.
- **QA gate:** On first subscription save, the app asks notification permission. A local notification fires 3 days before `nextBillDate` at the chosen hour on a real device. If that sub's payment method is at risk, the notification text mentions the low balance.

### US-12 — Home Screen widget
As a user, I want my monthly total and next payment on my Home Screen.
- **QA gate:** Small and medium widgets show the monthly total and the next upcoming payment (name, amount, days away). After adding a sub in the app, the widget updates to reflect the new next payment.

### US-13 — Free tier limit & unlock
As a free user, I want to add up to 5 subs; to add more I unlock Pro.
- **QA gate:** Adding a 6th subscription opens the paywall instead of saving. After purchase (or Restore), the 6th save succeeds. A lapsed payer can still read/see existing data but cannot add more.

---

## 4. Feature Specs

Each feature references the exact rules from the plan. **Foundation (§4.1) must exist before anything else builds.**

### 4.1 Data Model (Foundation — serial, blocks everything)

**Subscription** fields (per plan):
`name String`; `price Double` (per cycle); `cycleRaw String` (backing `BillingCycle`); `firstBillDate Date` (anchor); `categoryRaw String` (backing `Category`); `remindMe Bool`; `notes String`; `createdAt Date`; `paymentMethod PaymentMethod?` (SwiftData relationship).

**PaymentMethod** fields (per plan):
`name String` (free text e.g. Dana/Chase/Nubank); `balance Double` (manual); `balanceUpdatedAt Date`; `trackBalance Bool`; `subscriptions [Subscription]` (inverse relationship).

**Rules (per plan):**
- `PaymentMethod` is **auto-created** when the user types a new name.
- **Case-insensitive, trimmed matching** to avoid `dana` vs `Dana` duplicates.
- Autocomplete pulls from existing `PaymentMethod` records.

**Enums (per plan):**
- `BillingCycle`: `weekly | monthly | yearly`. Needs `label` (display string).
- `Category`: `entertainment | work | health | utilities | other`. Needs `label` (display) **and** `icon` (SF Symbol name).

**COMPUTED — DO NOT STORE (per plan):** Store only `firstBillDate` and cycle.
- `nextBillDate` = next occurrence of `firstBillDate` at the cycle interval at/after today. Use `Calendar.current`. Handle month-end (a sub billed on the 31st in a 30-day month must not break).
- `monthlyCost`: weekly → `price * 52 / 12`; monthly → `price`; yearly → `price / 12`.
- `yearlyCost` = `monthlyCost * 12`.
- `daysUntilNextBill` = whole days from today → `nextBillDate`.

> Exact frozen signatures for the above live in **§5.2 FROZEN INTERFACES**. Build against those.

**IMPORTANT (per plan's EXISTING CODE note):** `Models/Subscription.swift` does **NOT** exist on disk yet; the `Models/` folder is absent. Build foundation from scratch. The `paymentMethod` relationship is added when `PaymentMethod.swift` is created.

**Currency:** format with `Decimal` + `FormatStyle.currency`. Never string-concatenate money.

### 4.2 Home

- Header: monthly + yearly totals in the chosen currency.
- Balance warning banner: shown **only when at risk** (see §4.6).
- List of subs sorted by `nextBillDate` **ascending**.
- Each row: category icon, name, price, payment method name, "in X days".
- Swipe to delete.
- Empty state with "Add your first subscription" CTA.
- "+" top right opens the Add sheet.

### 4.3 Insights

- Pie chart: spend by **category** (Swift Charts).
- Pie chart: spend by **payment method** (the key differentiator).
- List: **top 5** most expensive subs by monthly cost.
- Empty state when there is no data.

### 4.4 Settings

- Currency picker (single, whole app; no FX).
- Notification time picker (the hour reminders fire).
- Manage payment methods: list, edit name, edit balance, toggle `trackBalance`.
- "Unlock Pro" → paywall.
- **"Restore Purchases" button — REQUIRED** (Apple rejects without it). Never cut.
- Privacy policy link.
- App version.

### 4.5 Add/Edit Sheet

Opens as a **bottom sheet**. Fields in this exact order:
1. name
2. price (decimal keypad)
3. billing cycle (segmented)
4. first bill date (date picker)
5. category (picker with icons)
6. payment method (text + autocomplete from existing)
7. "Remind me 3 days before" toggle
8. notes (optional, multiline)

**Save is disabled until name + price are valid.**

### 4.6 Balance Warning

For each `PaymentMethod` where `trackBalance == true`:
- Sum `price` of all linked subs billing in the **next 7 days**.
- If `sum > balance` → flag **AT RISK**; show a warning banner on Home **and** in the renewal notification.
- If `balanceUpdatedAt` is **older than 14 days** → show "balance may be out of date" **instead** of a hard warning. **Don't cry wolf on stale data.**

> Exact frozen signature in **§5.2**.

### 4.7 Widget (WidgetKit)

- Sizes: **small + medium**.
- Shows monthly total + next upcoming payment (name, amount, days away).
- Widget is a **separate process**; it can only read the DB via a shared **App Group**.
- Set up the App Group in Signing & Capabilities for **BOTH** app + widget targets; point the SwiftData `ModelConfiguration` at the shared group URL.
- Call `WidgetCenter.shared.reloadAllTimelines()` after any data change.

### 4.8 Notifications

- **Local only** (`UNUserNotificationCenter`), no push.
- Ask permission **on first subscription save**, not at launch.
- Schedule **3 days before** each `nextBillDate` at the user's chosen hour.
- **Cancel + reschedule** on any create/edit/delete.
- If the payment method is at risk, change the notification text to mention low balance.
- iOS caps pending notifications at **64** → schedule only the **next occurrence per subscription**, and reschedule on app open.

### 4.9 Monetization (RevenueCat)

- Free tier max **5 subscriptions**; the **6th opens the paywall**.
- Paid = monthly sub; consider a one-time **lifetime unlock** too (same code, converts better for utility apps).
- Prices are set in App Store Connect per country — **do NOT hardcode**; read from the RevenueCat offering object.
- RevenueCat is free until $2,500/mo revenue.
- **Never gate existing user data behind the paywall.** A lapsed payer keeps read access; they just can't add more.

---

## 5. Workstream Map

**Rule of parallelism:** Foundation serializes FIRST and blocks everyone. After foundation lands, agents work in parallel because **they own different folders and never edit the same files**. Before any two agents build in parallel, the interface between them is frozen in **§5.2**.

### 5.1 Workstreams

| Workstream | Owner agent | Files / folders it may touch | Consumes | Produces | "Done" gate |
|---|---|---|---|---|---|
| **W0 — Foundation** (serial, blocks all) | tech-lead | `Models/Subscription.swift`, `Models/PaymentMethod.swift`, SwiftData `ModelContainer` / `ModelConfiguration` (shared App Group URL), enums | The plan's data model + §5.2 contract | Compiling `@Model` types + enums + container; the `paymentMethod` relationship + inverse | Project builds; an in-memory insert of a Subscription + PaymentMethod round-trips; §5.2 signatures exist as declared stubs. **No other workstream starts until this passes.** |
| **W1 — Services** | tech-lead | `Services/` only | W0 models + §5.2 frozen signatures | Date math (`nextBillDate`, `monthlyCost`, `yearlyCost`, `daysUntilNextBill`), totals, at-risk detection, payment-method match/autocomplete helper | Unit tests green for date math (incl. month-end 31st) + at-risk + 14-day stale rule |
| **W2 — Views/UI** | ui-ux-designer | `Views/`, `Components/` only | W0 models + §5.2 signatures (calls Services; does not implement them) | Home, Insights, Settings, Add/Edit sheet, balance banner, empty states, paywall UI | Every screen renders against seeded data; Save-disabled rule works; matches §4 specs |
| **W3 — Widget** | tech-lead | Widget target files + shared App Group config | W0 container (shared group URL) + W1 totals/next-payment helper | Small + medium widget showing monthly total + next payment | Widget shows a real number on Home Screen; updates after a data change |
| **W4 — Notifications** | tech-lead | `Services/NotificationService.swift` (own file in Services/) | W1 `nextBillDate` + at-risk | Permission-on-first-save, schedule 3 days before, cancel+reschedule, at-risk text, ≤64 cap | Real notification arrives on a real device |
| **W5 — Monetization** | tech-lead | `Services/PurchaseService.swift` + paywall wiring | RevenueCat offering; W2 paywall UI shell | 5-sub gate, paywall on 6th, Restore Purchases, read-access-for-lapsed | Adding 6th opens paywall; purchase/restore unlocks; existing data never gated |
| **W6 — QA/Tests** | qa-engineer | `Tests/` only | All above + §5.2 signatures | Unit tests (Services math, at-risk, stale rule), gate checklists | Week gates in §6 have written pass/fail evidence |

**No-collision guarantee:** tech-lead owns `Models/`, `Services/`, Widget target, App Group config. ui-ux-designer owns `Views/` + `Components/`. qa-engineer owns `Tests/`. These sets do not overlap. The one shared surface — the interface — is frozen below.

### 5.2 FROZEN INTERFACES (Contract-First)

> **This is the contract that lets UI and Services build in parallel.** UI codes against these signatures while Services implements the bodies. **Do not change a signature without updating this section and notifying all agents.** Names, types, and cases here are authoritative.

#### 5.2.1 `Subscription` model — full field list

```swift
@Model
final class Subscription {
    var name: String
    var price: Double            // per cycle
    var cycleRaw: String         // backing storage for BillingCycle
    var firstBillDate: Date      // anchor; nextBillDate is computed, never stored
    var categoryRaw: String      // backing storage for Category
    var remindMe: Bool
    var notes: String
    var createdAt: Date
    var paymentMethod: PaymentMethod?   // SwiftData relationship
}
```

#### 5.2.2 `PaymentMethod` model — full field list

```swift
@Model
final class PaymentMethod {
    var name: String             // free text, e.g. Dana / Chase / Nubank
    var balance: Double          // manual entry
    var balanceUpdatedAt: Date
    var trackBalance: Bool
    @Relationship(inverse: \Subscription.paymentMethod)
    var subscriptions: [Subscription]   // inverse relationship
}
```

#### 5.2.3 `BillingCycle` enum — cases + `label`

```swift
enum BillingCycle: String, CaseIterable {
    case weekly
    case monthly
    case yearly

    var label: String { get }    // display string, e.g. "Weekly" / "Monthly" / "Yearly"
}
```

#### 5.2.4 `Category` enum — cases + `label` + `icon`

```swift
enum Category: String, CaseIterable {
    case entertainment
    case work
    case health
    case utilities
    case other

    var label: String { get }    // display string
    var icon: String { get }     // SF Symbol name
}
```

#### 5.2.5 Services — date math (frozen signatures)

Implemented on `Subscription` as computed properties (keeps logic testable; views read them):

```swift
extension Subscription {
    var cycle: BillingCycle { get }          // maps cycleRaw -> BillingCycle
    var category: Category { get }            // maps categoryRaw -> Category

    var nextBillDate: Date { get }           // next occurrence of firstBillDate at cycle interval, at/after today; Calendar.current; month-end safe
    var monthlyCost: Double { get }          // weekly: price*52/12 ; monthly: price ; yearly: price/12
    var yearlyCost: Double { get }           // monthlyCost * 12
    var daysUntilNextBill: Int { get }       // whole days from today to nextBillDate
}
```

#### 5.2.6 Services — balance warning / at-risk detection (frozen signatures)

```swift
enum BalanceStatus: Equatable {
    case ok
    case atRisk(shortfall: Double)   // sum of next-7-day subs exceeds balance
    case stale                       // balanceUpdatedAt older than 14 days -> "balance may be out of date"
}

enum BalanceService {
    // Sum price of subs on `method` billing within the next 7 days from `today`.
    static func upcomingChargeTotal(for method: PaymentMethod,
                                    from today: Date = .now) -> Double

    // Full status. Rules:
    //  - trackBalance == false            -> .ok
    //  - balanceUpdatedAt > 14 days old   -> .stale  (checked BEFORE at-risk; don't cry wolf)
    //  - upcomingChargeTotal > balance    -> .atRisk(shortfall:)
    //  - otherwise                        -> .ok
    static func status(for method: PaymentMethod,
                       from today: Date = .now) -> BalanceStatus
}
```

> **Freeze note on ordering:** the 14-day stale check runs **before** the at-risk check. A stale balance yields `.stale`, never `.atRisk`.

---

## 6. Milestone Gates (Week 1–4)

Each gate is a single pass/fail check on a real build (device where noted).

| Week | Gate | Pass / Fail check |
|---|---|---|
| **Week 1** | Persistence | Add a sub, force-quit, reopen → **data still there**. PASS if the row survives; FAIL otherwise. |
| **Week 2** | Notifications | A **real notification arrives on a real device** 3 days before, at the chosen hour. PASS if it fires; FAIL otherwise. |
| **Week 3** | Widget | Widget shows a **real number on the Home Screen** and updates after a data change. PASS if the number is correct/live; FAIL otherwise. |
| **Week 4** | Submission | **"Waiting for Review"** in App Store Connect. PASS if the build is submitted with paywall + Restore Purchases + privacy manifest + privacy policy URL; FAIL otherwise. |

**Cut order if behind (per plan):** widget → second chart → balance warning. **Never cut paywall or Restore Purchases.**

**App Store lead-time items to start early (flagged):**
1. Pay the **$99/yr Apple Developer Program** in Week 1 (approval takes days).
2. Apply to the **Small Business Program** early (free; drops Apple's cut 30%→15% under $1M/yr).
3. Add `PrivacyInfo.xcprivacy` (required even though the app collects no data; RevenueCat ships its own).
4. Publish a **privacy policy URL** (free GitHub Pages is fine).
5. Prepare **iPhone 6.9" screenshots**.
6. Search the App Store for the name first ("Subscription Tracker" is crowded).

---

## 7. Feature BUILD ORDER (pipeline)

Build in this order. Each stage lists its dependency so the pipeline is unambiguous.

- **A. Foundation** (models + enums + SwiftData container) — **SERIAL, blocks everything.** Depends on: nothing. Unblocks: all.
- **B. Home** — depends on A (needs models + `nextBillDate`, `monthlyCost`, `yearlyCost`, `daysUntilNextBill`). This is the app's spine; build it first after foundation.
- **C. Add/Edit sheet** — depends on A; needed to create data B displays (incl. payment-method auto-create + case-insensitive match).
- **D. Settings** — depends on A + C (manages payment methods, currency, reminder hour).
- **E. Insights** — depends on A + B data (charts + top-5 by monthly cost).
- **F. Balance warning** — depends on A + C + D (needs `trackBalance`, `balance`, `balanceUpdatedAt`) and §5.2.6 `BalanceService`.
- **G. Notifications** — depends on A + C + F (uses `nextBillDate` and at-risk status for text).
- **H. Widget** — depends on A + B (monthly total + next payment) and the shared App Group container.
- **I. RevenueCat** — depends on A + C (gate the 6th add on the paywall; Restore Purchases in Settings/D).

**Parallelism note:** After **A**, Services (W1) and Views (W2) proceed in parallel against §5.2. Within the UI stream the screen order is **B → C → D → E**. Widget (H), Notifications (G), and RevenueCat (I) are tech-lead streams that attach once their dependencies (above) are in.

---

## 8. Open Questions (developer decision needed)

Only one item needs the developer to choose. Everything else is locked by the plan.

**Q1 — Lifetime unlock alongside the monthly sub?**
The plan says paid = monthly sub, and to *consider* a one-time lifetime unlock ("same code, converts better for utility apps"). This is optional and affects only the RevenueCat offering config, not the frozen interfaces.

- **FAST:** Ship monthly sub only. Least App Store Connect setup; decide lifetime later. (Recommended for hitting the Week-4 gate.)
- **BALANCED:** Ship monthly sub + one lifetime unlock product. Small extra setup in App Store Connect; both read from the same RevenueCat offering object (no hardcoded prices).
- **AMBITIOUS:** Monthly + annual + lifetime tiers. More price/localization setup and more paywall UI; higher risk to the Week-4 submission date.

> This does not block any parallel work. W5 (Monetization) can start against FAST and add products later without touching §5.2.
