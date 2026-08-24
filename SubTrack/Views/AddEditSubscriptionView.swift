import SwiftUI
import SwiftData

// The Add / Edit sheet. One view serves BOTH modes: pass an existing
// Subscription to edit it, or nil (the default) to add a new one. Presented as
// a sheet from Home. Heavy logic (payment-method dedup) lives in
// PaymentMethodService — this view just collects input and validates it.
struct AddEditSubscriptionView: View {
    // dismiss closes the sheet; modelContext is how we write (insert/mutate).
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // The subscription being edited, or nil in add mode. Held weakly-typed as an
    // optional so the same body drives both flows.
    private let subscriptionToEdit: Subscription?

    // ── Form field state ────────────────────────────────────────────────────
    // Price is kept as raw text (not a Double) because a decimal-pad field is a
    // string the user is mid-typing; we parse to Double only when validating/saving.
    @State private var name: String = ""
    @State private var priceText: String = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var firstBillDate: Date = .now
    @State private var category: Category = .other
    @State private var paymentMethodName: String = ""
    @State private var remindMe: Bool = true
    @State private var notes: String = ""

    // Live autocomplete matches for the payment-method field, refreshed as the
    // user types. Populated from PaymentMethodService.suggestions(...).
    @State private var paymentSuggestions: [PaymentMethod] = []

    // Convenience: are we editing an existing record?
    private var isEditing: Bool { subscriptionToEdit != nil }

    // Public initializer — nil means "add mode".
    init(subscriptionToEdit: Subscription? = nil) {
        self.subscriptionToEdit = subscriptionToEdit
    }

    // ── Validation ──────────────────────────────────────────────────────────
    // Parse the raw price text to a Double. Returns nil for empty/garbage input.
    // Uses the current locale so a user typing "1,50" (comma decimal) also parses.
    private var parsedPrice: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Try the plain Double() first (dot decimals), then a locale-aware number
        // formatter so comma-decimal locales work too.
        if let value = Double(trimmed) { return value }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }

    // Save is allowed only when the name is non-empty AND the price parses to a
    // strictly-positive number. This is the exact rule that disables the button.
    private var isValid: Bool {
        let nameOK = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let priceOK = (parsedPrice ?? 0) > 0
        return nameOK && priceOK
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1) NAME
                Section {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Subscription name")
                }

                // 2) PRICE — raw decimal number; currency symbol is a display
                // concern elsewhere, so we never show/parse a symbol here.
                Section {
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)   // numeric pad with a decimal point
                        .accessibilityLabel("Price per billing cycle")
                }

                // 3) BILLING CYCLE — segmented control over every case.
                Section {
                    Picker("Billing cycle", selection: $cycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { c in
                            Text(c.label).tag(c)   // tag ties the row to the enum value
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 4) FIRST BILL DATE — date only, no time component.
                Section {
                    DatePicker("First bill date",
                               selection: $firstBillDate,
                               displayedComponents: .date)
                }

                // 5) CATEGORY — menu picker showing the SF Symbol + label per case.
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                // 6) PAYMENT METHOD — free-text field with live autocomplete.
                Section {
                    TextField("Payment method", text: $paymentMethodName)
                        .accessibilityLabel("Payment method")
                        // Recompute suggestions on every keystroke.
                        .onChange(of: paymentMethodName) { _, newValue in
                            paymentSuggestions = PaymentMethodService.suggestions(
                                matching: newValue, in: modelContext)
                        }

                    // Show matching existing methods as tappable rows. Tapping one
                    // fills the field (and clears the list via the onChange above).
                    ForEach(paymentSuggestions) { method in
                        Button {
                            paymentMethodName = method.name
                        } label: {
                            HStack {
                                Text(method.name)
                                Spacer()
                                Image(systemName: "arrow.up.left")   // "use this" affordance
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // Don't suggest the exact string already typed — it's redundant.
                        .opacity(method.name.caseInsensitiveCompare(
                            paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame ? 0.4 : 1)
                    }
                } header: {
                    Text("Payment method")
                } footer: {
                    // Explain the dedup so the learning dev understands the behavior.
                    Text("Existing methods are matched case-insensitively, so \"dana\" and \"Dana\" won't create duplicates.")
                }

                // 7) REMINDER — persists the bool only. Feature G does the actual
                // scheduling; we just store the user's intent here.
                Section {
                    Toggle("Remind me 3 days before", isOn: $remindMe)
                    // TODO (Feature G): request notification permission on first
                    // save + schedule the reminder based on this bool. Leave hook.
                }

                // 8) NOTES — optional, multi-line (grows vertically as typed).
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)   // start at 3 rows, grow to 6
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle(isEditing ? "Edit Subscription" : "New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel — leave without saving.
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel and discard changes")
                }
                // Save — disabled until the form is valid.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!isValid)   // the real Save-disabled rule
                        .accessibilityLabel("Save subscription")
                }
            }
            // Prime the form: in edit mode, copy the record's current values into
            // the fields once when the sheet appears. In add mode, seed the
            // suggestion list with all existing methods.
            .onAppear(perform: primeForm)
        }
    }

    // Load existing values into the @State fields for edit mode.
    private func primeForm() {
        if let sub = subscriptionToEdit {
            name = sub.name
            // Show the stored Double as plain text for the decimal field.
            priceText = String(sub.price)
            cycle = sub.cycle
            firstBillDate = sub.firstBillDate
            category = sub.category
            paymentMethodName = sub.paymentMethod?.name ?? ""
            remindMe = sub.remindMe
            notes = sub.notes
        }
        // Populate the initial suggestion list from whatever's typed (empty in
        // add mode -> all methods).
        paymentSuggestions = PaymentMethodService.suggestions(
            matching: paymentMethodName, in: modelContext)
    }

    // Persist the form. Guarded by isValid (the button is disabled otherwise, but
    // we re-check defensively before writing).
    private func save() {
        guard isValid, let price = parsedPrice else { return }

        // Resolve the typed payment-method name to a real (deduped) PaymentMethod,
        // or nil if the field is blank. findOrCreate inserts a new one if needed.
        let method = PaymentMethodService.findOrCreate(name: paymentMethodName, in: modelContext)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let sub = subscriptionToEdit {
            // EDIT — mutate the existing record in place.
            sub.name = trimmedName
            sub.price = price
            sub.cycleRaw = cycle.rawValue
            sub.firstBillDate = firstBillDate
            sub.categoryRaw = category.rawValue
            sub.remindMe = remindMe
            sub.notes = notes
            sub.paymentMethod = method
        } else {
            // TODO (Feature I): before inserting a NEW subscription, check the
            // 5-subscription free-tier limit and open the paywall instead of
            // saving. Leave this hook — do not implement the gate here.

            // ADD — build a fresh Subscription and insert it into the store.
            let sub = Subscription(
                name: trimmedName,
                price: price,
                cycle: cycle,
                firstBillDate: firstBillDate,
                category: category,
                remindMe: remindMe,
                notes: notes,
                paymentMethod: method
            )
            modelContext.insert(sub)
        }

        // TODO (Feature G): on first successful save, request notification
        // permission and schedule the "3 days before" reminder when remindMe is on.

        dismiss()
    }
}

// MARK: - Previews
// Both flows share one preview container so seeded methods/subscriptions are
// consistent across the add and edit cases.

#Preview("Add") {
    let container = Persistence.makePreviewContainer()
    // Seed a couple of payment methods so autocomplete has something to show.
    container.mainContext.insert(PaymentMethod(name: "Dana"))
    container.mainContext.insert(PaymentMethod(name: "Chase"))
    return AddEditSubscriptionView()
        .modelContainer(container)
}

#Preview("Edit") {
    let container = Persistence.makePreviewContainer()
    let context = container.mainContext
    let dana = PaymentMethod(name: "Dana")
    context.insert(dana)
    // Seed one subscription to drive the edit case.
    let sub = Subscription(
        name: "Spotify",
        price: 11.99,
        cycle: .monthly,
        firstBillDate: .now,
        category: .entertainment,
        remindMe: true,
        notes: "Family plan",
        paymentMethod: dana
    )
    context.insert(sub)
    return AddEditSubscriptionView(subscriptionToEdit: sub)
        .modelContainer(container)
}
