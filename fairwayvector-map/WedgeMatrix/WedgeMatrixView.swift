import SwiftUI
import UIKit

// Ported from fairwayvector-wedge-matrix, presented as a standalone feature from this app's Home tab.

struct WedgeMatrixView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("wedgeMatrix.wedges") private var storedWedges = ""
    @AppStorage("wedgeMatrix.distanceUnit") private var selectedUnitRawValue = WedgeDistanceUnit.yards.rawValue
    @State private var wedges: [Wedge] = Wedge.defaults
    @State private var selectedTrajectory: WedgeTrajectory = .stock
    @State private var targetDistance = 92.0
    @State private var selectorElevationMeters = 0.0
    @State private var selectorPinFraction = 0.5
    @State private var showAddClub = false

    private var bagWedges: [Wedge] {
        wedges.filter(\.isInBag)
    }

    private var selectedUnit: WedgeDistanceUnit {
        WedgeDistanceUnit(rawValue: selectedUnitRawValue) ?? .yards
    }

    private var selectedUnitBinding: Binding<WedgeDistanceUnit> {
        Binding(get: { selectedUnit }, set: { selectedUnitRawValue = $0.rawValue })
    }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        WedgeHomeOverviewCard(wedges: wedges, bagWedges: bagWedges)
                        WedgeCurrentBagCard(wedges: bagWedges, unit: selectedUnit)
                        WedgeBagNotesCard()
                    }
                    .padding()
                }
                .background(FairwayVectorColors.background)
                .navigationTitle("Wedge Matrix")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                WedgeClubSelectorView(
                    wedges: bagWedges,
                    unit: selectedUnit,
                    targetDistance: $targetDistance,
                    elevationMeters: $selectorElevationMeters,
                    pinFraction: $selectorPinFraction
                )
                .navigationTitle("Club Selector")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Club Selector", systemImage: "target") }

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        WedgeTrajectoryPicker(selectedTrajectory: $selectedTrajectory)
                        WedgeMatrixCard(wedges: bagWedges, trajectory: selectedTrajectory, unit: selectedUnit)
                    }
                    .padding()
                }
                .background(FairwayVectorColors.background)
                .navigationTitle("Matrix")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Matrix", systemImage: "square.grid.3x3") }

            NavigationStack {
                WedgeBagManagementList(wedges: $wedges, unit: selectedUnit)
                    .navigationTitle("Bag")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Add Club", systemImage: "plus") { showAddClub = true }
                                .labelStyle(.iconOnly)
                                .accessibilityLabel("Add Club")
                        }
                    }
                    .sheet(isPresented: $showAddClub) {
                        WedgeAddClubView(wedges: $wedges, unit: selectedUnit)
                    }
            }
            .tabItem { Label("Bag", systemImage: "figure.golf") }
        }
        .tint(FairwayVectorColors.navy)
        .onAppear(perform: loadStoredWedges)
        .onChange(of: wedges) { _, newValue in
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8) else { return }
            storedWedges = encoded
        }
    }

    private func loadStoredWedges() {
        guard !storedWedges.isEmpty,
              let data = storedWedges.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Wedge].self, from: data),
              !decoded.isEmpty else { return }
        wedges = decoded
    }
}

private struct WedgeHomeOverviewCard: View {
    var wedges: [Wedge]
    var bagWedges: [Wedge]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                FairwayVectorMark()
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wedge Matrix")
                        .font(.title2.bold())
                        .foregroundStyle(FairwayVectorColors.navy)
                    Text("Build a personal partial-shot chart from the wedges you carry and the numbers you trust.")
                        .font(.subheadline)
                        .foregroundStyle(FairwayVectorColors.slate)
                }
            }
            HStack(spacing: 12) {
                WedgeMetricCard(title: "Wedges", value: "\(wedges.count)", systemImage: "list.bullet")
                WedgeMetricCard(title: "In Bag", value: "\(bagWedges.count)", systemImage: "bag")
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeCurrentBagCard: View {
    var wedges: [Wedge]
    var unit: WedgeDistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Bag")
                .font(.headline)

            if wedges.isEmpty {
                Text("No wedges selected for the bag.")
                    .font(.subheadline)
                    .foregroundStyle(FairwayVectorColors.slate)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(wedges) { wedge in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wedge.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(FairwayVectorColors.navy)
                            if let brand = wedge.brandDisplay {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(FairwayVectorColors.slate)
                            }
                        }
                        Spacer()
                        Text(unit.format(wedge.fullCarry))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FairwayVectorColors.charcoal)
                            .monospacedDigit()
                    }
                    .padding(12)
                    .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeBagNotesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Matrix notes", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(FairwayVectorColors.navy)
            VStack(alignment: .leading, spacing: 10) {
                WedgeNoteRow(value: "50%", text: "Clock-face or waist-high swings")
                WedgeNoteRow(value: "75%", text: "Controlled three-quarter tempo")
                WedgeNoteRow(value: "Full", text: "Stock full carry, not total distance")
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeNoteRow: View {
    var value: String
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(FairwayVectorColors.surface)
                .frame(width: 48)
                .padding(.vertical, 6)
                .background(FairwayVectorColors.navy, in: Capsule())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(FairwayVectorColors.slate)
            Spacer()
        }
    }
}

private struct WedgeMetricCard: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(FairwayVectorColors.orange)
                .frame(width: 34, height: 34)
                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(FairwayVectorColors.slate)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(FairwayVectorColors.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeTrajectoryPicker: View {
    @Binding var selectedTrajectory: WedgeTrajectory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trajectory")
                .font(.headline)
            Picker("Trajectory", selection: $selectedTrajectory) {
                ForEach(WedgeTrajectory.allCases) { trajectory in
                    Label(trajectory.title, systemImage: trajectory.systemImage).tag(trajectory)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeMatrixCard: View {
    var wedges: [Wedge]
    var trajectory: WedgeTrajectory
    var unit: WedgeDistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(trajectory.title) Trajectory")
                        .font(.headline)
                    Text("Carry distances adjusted for \(trajectory.title.lowercased()) shots")
                        .font(.caption)
                        .foregroundStyle(FairwayVectorColors.slate)
                }
                Spacer()
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(FairwayVectorColors.orange)
            }

            if wedges.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bag.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(FairwayVectorColors.slate)
                    Text("No Wedges In Bag")
                        .font(.headline)
                    Text("Open Bag and add clubs to your bag.")
                        .font(.subheadline)
                        .foregroundStyle(FairwayVectorColors.slate)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Club")
                            .font(.caption.bold())
                            .foregroundStyle(FairwayVectorColors.slate)
                            .frame(width: 72, alignment: .leading)
                        ForEach(SwingLength.allCases) { swing in
                            Text(swing.title)
                                .font(.caption.bold())
                                .foregroundStyle(FairwayVectorColors.slate)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    ForEach(wedges) { wedge in
                        HStack(spacing: 8) {
                            Text(wedge.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(FairwayVectorColors.navy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(width: 72, alignment: .leading)

                            ForEach(SwingLength.allCases) { swing in
                                let carry = wedge.carry(for: trajectory, swing: swing)
                                Text("\(unit.format(carry)) \(unit.abbreviation)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FairwayVectorColors.charcoal)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(swing.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeBagManagementList: View {
    @Binding var wedges: [Wedge]
    var unit: WedgeDistanceUnit

    var body: some View {
        List {
            Section {
                if wedges.isEmpty {
                    ContentUnavailableView(
                        "No Clubs",
                        systemImage: "bag.badge.questionmark",
                        description: Text("Tap plus to add the clubs you own.")
                    )
                    .foregroundStyle(FairwayVectorColors.slate)
                } else {
                    ForEach(wedges) { wedge in
                        if let wedgeBinding = binding(for: wedge) {
                            HStack {
                                NavigationLink {
                                    WedgeClubDetailView(wedge: wedgeBinding, unit: unit)
                                } label: {
                                    WedgeClubInventoryRow(wedge: wedge, unit: unit)
                                }
                                Toggle("In Bag", isOn: wedgeBinding.isInBag)
                                    .labelsHidden()
                                    .tint(FairwayVectorColors.navy)
                            }
                        }
                    }
                    .onDelete(perform: deleteWedges)
                }
            } header: {
                HStack {
                    Text("Club Inventory")
                    Spacer()
                    Text("In Bag")
                        .font(.caption.weight(.semibold))
                }
            }
            .listRowBackground(FairwayVectorColors.surface)
        }
        .scrollContentBackground(.hidden)
        .background(FairwayVectorColors.background)
    }

    private func binding(for wedge: Wedge) -> Binding<Wedge>? {
        guard wedges.contains(where: { $0.id == wedge.id }) else { return nil }
        return Binding(
            get: { wedges.first(where: { $0.id == wedge.id }) ?? wedge },
            set: { updatedWedge in
                guard let index = wedges.firstIndex(where: { $0.id == wedge.id }) else { return }
                wedges[index] = updatedWedge
            }
        )
    }

    private func deleteWedges(offsets: IndexSet) {
        wedges.remove(atOffsets: offsets)
    }
}

private struct WedgeClubInventoryRow: View {
    var wedge: Wedge
    var unit: WedgeDistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wedge.name)
                .font(.subheadline.bold())
                .foregroundStyle(FairwayVectorColors.navy)
            if let brand = wedge.brandDisplay {
                Text(brand)
                    .font(.caption)
                    .foregroundStyle(FairwayVectorColors.slate)
            }
            Text("Stock: \(unit.format(wedge.fullCarry)) \(unit.abbreviation)")
                .font(.caption)
                .foregroundStyle(FairwayVectorColors.slate)
        }
    }
}

private struct WedgeClubDetailView: View {
    @Binding var wedge: Wedge
    let unit: WedgeDistanceUnit
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Wedge

    init(wedge: Binding<Wedge>, unit: WedgeDistanceUnit) {
        _wedge = wedge
        self.unit = unit
        _draft = State(initialValue: wedge.wrappedValue)
    }

    private var hasChanges: Bool {
        draft != wedge
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WedgeClubDistancesCard(wedge: $draft, unit: unit)
            }
            .padding()
        }
        .background(FairwayVectorColors.background)
        .navigationTitle(draft.name.isEmpty ? "Club" : draft.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    wedge = draft
                    dismiss()
                }
                .disabled(!hasChanges)
            }
        }
    }
}

private struct WedgeClubDistancesCard: View {
    @Binding var wedge: Wedge
    let unit: WedgeDistanceUnit
    @State private var drafts: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Distances")
                .font(.headline)
                .foregroundStyle(FairwayVectorColors.navy)

            ForEach(WedgeTrajectory.allCases) { trajectory in
                VStack(alignment: .leading, spacing: 8) {
                    Text(trajectory.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(FairwayVectorColors.slate)

                    HStack(spacing: 8) {
                        ForEach(SwingLength.allCases) { swing in
                            VStack(spacing: 4) {
                                Text(swing.title)
                                    .font(.caption)
                                    .foregroundStyle(FairwayVectorColors.slate)
                                WedgeDoneAccessoryNumberField(
                                    placeholder: "\(unit.format(wedge.carry(for: trajectory, swing: swing)))",
                                    text: draftBinding(for: trajectory, swing: swing),
                                    textAlignment: .center
                                )
                                .frame(height: 20)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FairwayVectorColors.charcoal)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(swing.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .onAppear(perform: loadDrafts)
        .onChange(of: unit) { _, _ in loadDrafts() }
    }

    private func draftBinding(for trajectory: WedgeTrajectory, swing: SwingLength) -> Binding<String> {
        let key = "\(trajectory.rawValue).\(swing.rawValue)"
        return Binding(
            get: { drafts[key] ?? "" },
            set: { value in
                drafts[key] = value
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    wedge.clearCarry(for: trajectory, swing: swing)
                    return
                }
                guard let number = Double(trimmed), number > 0 else { return }
                let carryInYards = unit == .yards ? number : number / 0.9144
                wedge.setCarry(carryInYards, for: trajectory, swing: swing)
            }
        )
    }

    private func loadDrafts() {
        var values: [String: String] = [:]
        for trajectory in WedgeTrajectory.allCases {
            for swing in SwingLength.allCases {
                let key = "\(trajectory.rawValue).\(swing.rawValue)"
                if let override = wedge.overrideCarry(for: trajectory, swing: swing) {
                    let displayValue = unit == .yards ? override : override * 0.9144
                    values[key] = String(format: "%.0f", displayValue)
                } else {
                    values[key] = ""
                }
            }
        }
        drafts = values
    }
}

private struct WedgeAddClubView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var wedges: [Wedge]
    let unit: WedgeDistanceUnit
    @State private var name = ""
    @State private var brand = ""
    @State private var notes = ""
    @State private var isInBag = true
    @State private var stockDistanceText = "100"

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stockDistance: Double? {
        guard let value = Double(stockDistanceText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        return unit == .yards ? value : value / 0.9144
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WedgeClubFormCard(name: $name, brand: $brand, notes: $notes, isInBag: $isInBag)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stock distance")
                            .font(.headline)
                            .foregroundStyle(FairwayVectorColors.navy)
                        HStack {
                            WedgeDoneAccessoryNumberField(placeholder: "100% stock carry", text: $stockDistanceText)
                                .padding(10)
                                .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
                            Text(unit.abbreviation)
                                .foregroundStyle(FairwayVectorColors.slate)
                        }
                    }
                    .padding()
                    .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))

                    Text("You can fine-tune 50%, 75%, and low/high carries later from the club's detail page in Bag.")
                        .font(.caption)
                        .foregroundStyle(FairwayVectorColors.slate)
                }
                .padding()
            }
            .background(FairwayVectorColors.background)
            .navigationTitle("Add Club")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let stockDistance else { return }
                        wedges.append(
                            Wedge(
                                name: trimmedName,
                                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                fullCarry: stockDistance,
                                isInBag: isInBag
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || stockDistance == nil)
                }
            }
        }
    }
}

private struct WedgeClubFormCard: View {
    @Binding var name: String
    @Binding var brand: String
    @Binding var notes: String
    @Binding var isInBag: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Club")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                WedgeStyledTextField(title: "Name", text: $name)
                WedgeStyledTextField(title: "Brand optional", text: $brand)
            }

            Toggle("In Bag", isOn: $isInBag)
                .tint(FairwayVectorColors.navy)

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.subheadline.bold())
                    .foregroundStyle(FairwayVectorColors.navy)
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(FairwayVectorColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeStyledTextField: View {
    var title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .font(.subheadline)
            .foregroundStyle(FairwayVectorColors.charcoal)
            .padding(12)
            .background(FairwayVectorColors.conditionsSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WedgeDoneAccessoryNumberField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var textAlignment: NSTextAlignment = .right

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.keyboardType = .decimalPad
        textField.textAlignment = textAlignment
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Done", style: .done, target: textField, action: #selector(UITextField.resignFirstResponder))
        ]
        textField.inputAccessoryView = toolbar
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        textField.placeholder = placeholder
        textField.textAlignment = textAlignment
        if textField.text != text {
            textField.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

#Preview {
    WedgeMatrixView()
}
