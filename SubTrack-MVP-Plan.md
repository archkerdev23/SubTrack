# SubTrack — Subscription & Bill Tracker
## MVP Build Plan (Agent Handoff Spec)

**Owner:** Solo indie developer
**Platform:** iOS only. Swift + SwiftUI. Xcode. App Store Connect.
**Do NOT suggest:** Android, web, Flutter, React Native, backend servers, hiring a team.
**Target market:** Worldwide.
**Estimated build time:** 4 weeks, solo.

---

## 1. What this app is

A local-only iOS app that tracks recurring subscriptions and bills.

The differentiator: it tracks **which payment method** each subscription is charged to
(e-wallet, bank, card), and warns the user when a wallet balance may be too low before
a renewal. Most competing apps only track the subscription, not the wallet behind it.

---

## 2. Locked decisions

| Area | Decision | Notes |
|---|---|---|
| Storage | **SwiftData** | Local only. No CloudKit in MVP. |
| Minimum iOS | **iOS 18** | Safe in 2026. |
| Monetization | **RevenueCat**, monthly subscription | Free tier limited to 5 subscriptions. |
| Payment method input | **Free text + autocomplete** | No fixed list — must work worldwide. |
| Balance warning | **In MVP** | Manual balance entry by user. |
| Currency | **Single currency picker in Settings** | No FX conversion in MVP. |
| Backend | **None** | Everything on-device. |

### Explicitly OUT of MVP (do not build)
- iCloud / CloudKit sync
- Bank or e-wallet API connection
- Multi-currency conversion
- User accounts or login
- iPad-specific layout
- Live Activities
- Custom dark mode theming (system dark mode only)

---

## 3. Data model

### Model: `Subscription`

| Field | Type | Notes |
|---|---|---|
| `name` | String | e.g. "Spotify" |
| `price` | Double | per cycle, not per month |
| `cycleRaw` | String | backing store for `BillingCycle` |
| `firstBillDate` | Date | anchor date for all future calculations |
| `categoryRaw` | String | backing store for `Category` |
| `remindMe` | Bool | renewal notification on/off |
| `notes` | String | optional |
| `createdAt` | Date | set on init |
| `paymentMethod` | `PaymentMethod?` | SwiftData relationship |

### Model: `PaymentMethod`

| Field | Type | Notes |
|---|---|---|
| `name` | String | free text, e.g. "Dana", "Chase", "Nubank" |
| `balance` | Double | manually entered by user |
| `balanceUpdatedAt` | Date | used to nudge "your balance is stale" |
| `trackBalance` | Bool | user can opt out per method |
| `subscriptions` | `[Subscription]` | inverse relationship |

**Rules:**
- `PaymentMethod` is created automatically when the user types a name that does not exist yet.
- Name matching is case-insensitive and trimmed, to avoid "dana" vs "Dana" duplicates.
- Autocomplete suggestions come from existing `PaymentMethod` records.

### Enums

```
BillingCycle: weekly | monthly | yearly
Category:     entertainment | work | health | utilities | other
```

Each enum needs a `label` (display string) and `Category` needs an `icon`
(SF Symbol name — Apple's free built-in icon set).

### Computed values — DO NOT STORE THESE

Store only `firstBillDate` and `cycle`. Calculate everything else, or editing a date
will produce stale data.

- `nextBillDate` — next occurrence of `firstBillDate` at `cycle` interval, at or after today.
  Use `Calendar.current`, not manual date math. Handle month-end edge cases
  (e.g. billed on the 31st in a 30-day month).
- `monthlyCost` — normalize price to monthly:
  - weekly → `price * 52 / 12`
  - monthly → `price`
  - yearly → `price / 12`
- `yearlyCost` — `monthlyCost * 12`
- `daysUntilNextBill` — whole days from today to `nextBillDate`

### Balance warning logic

For each `PaymentMethod` where `trackBalance == true`:

1. Sum the `price` of all linked subscriptions billing in the next 7 days.
2. If that sum > `balance`, flag the payment method as **at risk**.
3. Show a warning banner on Home and in the renewal notification.
4. If `balanceUpdatedAt` is older than 14 days, show "balance may be out of date" instead
   of a hard warning. Do not cry wolf on stale data.

---

## 4. Screens

Tab bar with 3 tabs. Add/Edit opens as a sheet (a card sliding up from the bottom).

### Tab 1 — Home
- Header: monthly total + yearly total, in the user's chosen currency
- Balance warning banner (only when a payment method is at risk)
- List of subscriptions, sorted by `nextBillDate` ascending
- Each row: category icon, name, price, payment method name, "in X days"
- Swipe to delete
- Empty state with a clear "Add your first subscription" call to action
- "+" button top right → opens Add sheet

### Tab 2 — Insights
- Pie chart: spend by **category** (Swift Charts, Apple's built-in chart library)
- Pie chart: spend by **payment method** ← key differentiator
- List: top 5 most expensive subscriptions by monthly cost
- Empty state when there is no data

### Tab 3 — Settings
- Currency picker (single currency for the whole app)
- Notification time picker (what hour of day reminders fire)
- Manage payment methods → list, edit name, edit balance, toggle `trackBalance`
- "Unlock Pro" button → paywall
- **"Restore Purchases" button — REQUIRED, Apple rejects paywalled apps without it**
- Privacy policy link
- App version number

### Sheet — Add / Edit Subscription
Fields, in this order:
1. Name (text)
2. Price (decimal keypad)
3. Billing cycle (segmented picker)
4. First bill date (date picker)
5. Category (picker with icons)
6. Payment method (text field with autocomplete from existing methods)
7. Remind me 3 days before (toggle)
8. Notes (optional, multi-line)

Save button disabled until name and price are valid.

---

## 5. Widget (WidgetKit)

Small + medium size. Shows:
- Monthly total
- Next upcoming payment (name, amount, days away)

**Critical:** the widget is a separate process. It cannot read the app's database
unless both share an **App Group** (a shared container both targets can access).
Set up the App Group in Signing & Capabilities for BOTH the app target and the widget
target, and point the SwiftData `ModelConfiguration` at the shared group URL.
Call `WidgetCenter.shared.reloadAllTimelines()` after any data change.

---

## 6. Notifications

- Local notifications only (`UNUserNotificationCenter`). No push server.
- Ask permission on first subscription save, not on app launch.
- Schedule 3 days before each `nextBillDate`, at the user's chosen hour.
- Cancel and reschedule whenever a subscription is created, edited, or deleted.
- If the payment method is flagged **at risk**, change the notification text to mention
  the low balance.
- iOS caps pending local notifications at 64. Schedule only the next occurrence per
  subscription, then reschedule on app open.

---

## 7. Monetization — RevenueCat

- Free tier: maximum **5 subscriptions**. Attempting a 6th opens the paywall.
- Paid tier: monthly subscription. Consider also offering a one-time lifetime unlock
  alongside it — RevenueCat handles both with the same code, and one-time pricing
  converts better for utility apps.
- Prices are set in App Store Connect, per country. Do not hardcode prices in the app —
  read them from RevenueCat's offering object so localized prices display correctly.
- RevenueCat is free until $2,500/month in tracked revenue.
- Never gate existing user data behind the paywall. If a paying user cancels, they keep
  read access to everything they already entered; they just cannot add more.

---

## 8. Timeline

### Week 1 — data works
- Day 1: Xcode project, folder structure, `Subscription` model
- Day 2: `PaymentMethod` model + relationship, SwiftData container setup
- Day 3: Date math (`nextBillDate`, `monthlyCost`) + unit-test it manually
- Day 4–5: Home list screen + Add/Edit sheet
- Day 6: Delete, swipe actions, empty states, autocomplete
- Day 7: Buffer

**Gate:** add a subscription, force-quit the app, reopen — data is still there.

### Week 2 — the good stuff
- Day 8: Totals header + currency formatting
- Day 9–10: Insights screen, both charts
- Day 11: Balance warning logic + banner
- Day 12–13: Local notifications
- Day 14: Buffer

**Gate:** a real notification arrives on a real device.

### Week 3 — widget + polish
- Day 15–17: App Group + widget
- Day 18: App icon, launch screen, empty-state copy
- Day 19: Accessibility pass — Dynamic Type, VoiceOver labels
- Day 20–21: Bug fixing on a real device

**Gate:** widget shows a real number on the Home Screen.

### Week 4 — money + shipping
- Day 22–24: RevenueCat integration, paywall UI, free limit, restore purchases
- Day 25: Privacy manifest, App Store Connect record, Small Business Program
- Day 26: Screenshots + app description + keywords
- Day 27: TestFlight, real-device testing
- Day 28: Submit for review

**Gate:** "Waiting for Review" in App Store Connect.

**If behind schedule, cut in this order:** widget → second chart → balance warning.
Never cut the paywall or restore purchases.

---

## 9. Code conventions

- SwiftUI only. No UIKit unless unavoidable.
- One view per file. Views live in `Views/`, models in `Models/`,
  business logic in `Services/`, reusable UI in `Components/`.
- Keep date math and balance logic in `Services/`, not inside views, so it stays testable.
- Use `@Query` for reading SwiftData, `modelContext` for writing.
- Format currency with `Decimal` + `FormatStyle.currency`, never string concatenation.
- Prefer computed properties over stored duplicates.
- Comment any non-obvious line in plain English — the developer is learning SwiftUI.
- When delivering code, always give the **whole file** plus its filename and folder path.

---

## 10. Existing code

`Models/Subscription.swift` is already written: `@Model` class with the fields above,
plus `BillingCycle` and `Category` enums with `label` and `icon`. It uses `cycleRaw` /
`categoryRaw` String storage with computed `cycle` / `category` accessors, because
SwiftData handles String storage more reliably than raw enums.

Note: the `paymentMethod` relationship is **not yet added** to that file. It must be added
when `PaymentMethod.swift` is created.

---

## 11. App Store requirements — do not skip

- **$99/year Apple Developer Program.** Pay in week 1; approval can take days.
- **Small Business Program.** Apply in App Store Connect immediately. Free. Drops Apple's
  cut from 30% to **15%** for revenue under $1M/year.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`). Required. This app collects no data,
  so the file is nearly empty — but it must exist. RevenueCat also ships its own manifest.
- **Restore Purchases button.** Mandatory for any paywall. Common rejection reason.
- **Screenshots.** iPhone 6.9" display size required. Budget half a day.
- **Privacy policy URL.** Required for apps with in-app purchase. A free GitHub Pages
  page is acceptable.
- **App name.** Search the App Store before committing — "Subscription Tracker" is crowded.
- **App Tracking Transparency** is NOT needed — this app tracks nothing across apps.
- First-time submissions often take longer than the usual 24–48 hour review.

---

## 12. How to work with the developer

- Simple everyday English. Short sentences. English is their second language.
- Explain every technical term the first time, in one line.
- Answer first, details after.
- For any decision, give exactly 3 options — FAST / BALANCED / AMBITIOUS — with time,
  cost, and the main tradeoff, then a comparison table, then a recommendation.
  Never decide silently.
- Numbered steps, one action per step. Say exactly what to click and which file to open.
- After each step, say how to check it worked.
- Stop every 3–5 steps and ask "still working?"
- Warn early if any piece will take more than 2 weeks alone.
- Prefer free tools. Always state the price of paid ones.
- If something is unclear, ask ONE question, not five.
