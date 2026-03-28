//
//  CourseEditorSheet.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25 (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - Screen breathes like LiveRoundView (spacing, dividers, top bar, bottom pill)
//  - Big course name field (dominant) with calm separator
//  - 9/18 selector pills feel consistent and restrained
//  - Hole rows use the same row rhythm as LiveRound (vertical padding + typography)
//  - Tap Par or SI chip → picker sheet
//  - After sheet dismiss → returns to the last edited hole (no jump to top)
//  - Bottom "Save" pill matches LiveRound primary CTA
//

import SwiftUI
import SwiftData

struct CourseEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: Course?
    var onSave: (Course) -> Void = { _ in }

    @State private var name: String = ""
    @State private var holes: Int = 18
    @State private var pars: [Int] = Array(repeating: 4, count: 18)
    @State private var strokeIndex: [Int] = Array(1...18)
    @State private var isSaving: Bool = false

    // Hole picker sheet state
    @State private var editingHole: Int? = nil
    @State private var editingMode: HoleEditMode = .par

    // Restore scroll position after picker dismiss
    @State private var restoreHoleIndex: Int? = nil

    enum HoleEditMode { case par, si }

    init(existing: Course? = nil, onSave: @escaping (Course) -> Void = { _ in }) {
        self.existing = existing
        self.onSave = onSave
    }

    // NOTE: Chip sizing can be promoted into GSPUI later.
    private let chipHeight: CGFloat = 60
    private let chipCorner: CGFloat = 16
    private let chipWidth: CGFloat = 108

    private var accent: Color { .accentColor }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                        NotesScreenTitle(
                            existing == nil ? "New Course" : "Edit Course",
                            subtitle: "Tap a hole to set Par & SI"
                        )

                        // MARK: Course Name (dominant, Notes-like)
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Course name", text: $name)
                                .font(.system(size: 34, weight: .semibold, design: .default))
                                .foregroundStyle(NotesTheme.textPrimary)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)

                            Divider().opacity(0.25)
                        }
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, 2)

                        // MARK: Hole count selector (restrained, consistent)
                        HStack(spacing: 12) {
                            holesPill(9)
                            holesPill(18)
                            Spacer()
                        }
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, 2)

                        // MARK: Holes header
                        Text("Holes")
                            .font(.system(.title2, design: .default).weight(.semibold))
                            .foregroundStyle(NotesTheme.textPrimary)
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.top, 8)

                        // MARK: Holes list (LiveRound rhythm)
                        VStack(spacing: 0) {
                            ForEach(0..<holes, id: \.self) { i in
                                holeRow(i)
                                    .id(i)

                                if i != holes - 1 {
                                    GSPDivider(leading: GSPUI.Spacing.insetX)
                                }
                            }
                        }
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, GSPUI.Spacing.listTop)

                        Spacer(minLength: 28)
                            .padding(.bottom, 110) // space for bottom pill
                    }
                    .padding(.top, GSPUI.Spacing.pageTop)
                }
                .notesBackground()
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top) { topBar }

                bottomPill
            }
            .sheet(isPresented: Binding(
                get: { editingHole != nil },
                set: { if !$0 { editingHole = nil } }
            )) {
                holePickerSheet
            }
            .onAppear { hydrate() }
            .onChange(of: holes) { _ in normalizeArrays() }
            .onChange(of: editingHole) { newValue in
                // When opening: remember the hole index
                if let idx = newValue {
                    restoreHoleIndex = idx
                    return
                }

                // When closing: scroll back to the last edited hole (no jump to top)
                guard let idx = restoreHoleIndex else { return }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 60_000_000)

                    var txn = Transaction()
                    txn.animation = nil
                    withTransaction(txn) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Top bar (LiveRound canonical)

    private var topBar: some View {
        HStack {
            GSPIconPillButton(systemName: "chevron.left") {
                HapticsManager.light()
                dismiss()
            }

            Spacer()
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, GSPUI.Spacing.insetTopBarTop)
        .padding(.bottom, GSPUI.Spacing.insetTopBarBottom)
        .background(NotesTheme.bg)
    }

    // MARK: - Bottom Action Pill (canonical)

    private var bottomPill: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25)

            Button { saveAndDismiss() } label: {
                GSPPrimaryPill(
                    title: existing == nil ? "Save Course" : "Save Changes",
                    accent: accent
                )
                .opacity((canSave && !isSaving) ? 1.0 : 0.45)
                .padding(.horizontal, GSPUI.Spacing.insetX)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canSave && !isSaving)
        }
        .background(NotesTheme.bg)
    }

    // MARK: - Hole count pills (restrained)

    private func holesPill(_ n: Int) -> some View {
        let isSelected = (holes == n)

        return Button {
            holes = n
            normalizeArrays()
            HapticsManager.light()
        } label: {
            Text("\(n) holes")
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(isSelected ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(NotesTheme.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Value chips (Par / SI)

    private func holeValueButton(title: String, value: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textSecondary)

                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .frame(width: chipWidth, height: chipHeight)
            .background(
                RoundedRectangle(cornerRadius: chipCorner, style: .continuous)
                    .fill(Color.white.opacity(0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: chipCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: chipCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(value)")
    }

    // MARK: - Rows

    private func holeRow(_ i: Int) -> some View {
        let holeNumber = i + 1
        let par = safeGet(pars, i, fallback: 4)
        let si = safeGet(strokeIndex, i, fallback: min(holeNumber, 18))

        return HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {
            Text("Hole \(holeNumber)")
                .font(.system(size: 26, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                holeValueButton(title: "Par", value: "\(par)") {
                    restoreHoleIndex = i
                    editingHole = i
                    editingMode = .par
                    HapticsManager.light()
                }

                holeValueButton(title: "SI", value: "\(si)") {
                    restoreHoleIndex = i
                    editingHole = i
                    editingMode = .si
                    HapticsManager.light()
                }
            }
        }
        .padding(.vertical, GSPUI.Spacing.rowVPad)
    }

    // MARK: - Picker Sheet

    private var holePickerSheet: some View {
        let idx = editingHole ?? 0
        let holeNumber = idx + 1

        switch editingMode {
        case .par:
            return AnyView(
                ValuePickerSheet(
                    title: "Hole \(holeNumber) Par",
                    value: bind($pars, index: idx, fallback: 4),
                    range: 3...5
                )
            )
        case .si:
            return AnyView(
                ValuePickerSheet(
                    title: "Hole \(holeNumber) Stroke Index",
                    value: bind($strokeIndex, index: idx, fallback: min(holeNumber, 18)),
                    range: 1...18
                )
            )
        }
    }

    // MARK: - Save / Data

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func hydrate() {
        if let c = existing {
            name = c.name
            holes = c.totalHoles
            pars = Array(c.pars.prefix(holes))
            strokeIndex = Array(c.strokeIndex.prefix(holes))
        } else {
            name = ""
            holes = 18
            pars = Array(repeating: 4, count: holes)
            strokeIndex = Array(1...holes)
        }
        normalizeArrays()
    }

    private func normalizeArrays() {
        if pars.count < holes { pars += Array(repeating: 4, count: holes - pars.count) }
        if pars.count > holes { pars = Array(pars.prefix(holes)) }

        if strokeIndex.count < holes {
            let start = (strokeIndex.last ?? 0) + 1
            let end = start + (holes - strokeIndex.count) - 1
            if start <= end { strokeIndex += Array(start...end) }
            else { strokeIndex += Array(repeating: 1, count: holes - strokeIndex.count) }
        }
        if strokeIndex.count > holes { strokeIndex = Array(strokeIndex.prefix(holes)) }

        for i in 0..<holes {
            pars[i] = min(5, max(3, pars[i]))
            strokeIndex[i] = min(18, max(1, strokeIndex[i]))
        }
    }

    private func saveAndDismiss() {
        guard !isSaving else { return }
        isSaving = true

        normalizeArrays()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isSaving = false; return }

        if let c = existing {
            c.name = trimmed
            c.totalHoles = holes
            c.pars = Array(pars.prefix(holes))
            c.strokeIndex = Array(strokeIndex.prefix(holes))
            c.updatedAt = .now
            do { try context.save(); onSave(c) }
            catch { print("Course update save failed: \(error)"); isSaving = false; return }
        } else {
            let new = Course(
                name: trimmed,
                totalHoles: holes,
                pars: Array(pars.prefix(holes)),
                strokeIndex: Array(strokeIndex.prefix(holes)),
                createdAt: .now,
                updatedAt: .now
            )
            context.insert(new)
            do { try context.save(); onSave(new) }
            catch { print("Course create save failed: \(error)"); isSaving = false; return }
        }

        HapticsManager.success()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            dismiss()
        }
    }

    private func safeGet(_ arr: [Int], _ i: Int, fallback: Int) -> Int {
        (i >= 0 && i < arr.count) ? arr[i] : fallback
    }

    private func bind(_ array: Binding<[Int]>, index i: Int, fallback: Int) -> Binding<Int> {
        Binding<Int>(
            get: {
                let a = array.wrappedValue
                return (i >= 0 && i < a.count) ? a[i] : fallback
            },
            set: { newValue in
                var a = array.wrappedValue
                guard i >= 0 else { return }
                if i >= a.count {
                    a.append(contentsOf: Array(repeating: fallback, count: i - a.count + 1))
                }
                a[i] = newValue
                array.wrappedValue = a
            }
        )
    }
}
