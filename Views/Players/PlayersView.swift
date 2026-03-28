//
//  PlayersView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25  (LiveRoundView UI Source of Truth)
//  Timestamp: 2026-02-25  (America/Los_Angeles)
//
//  WHAT YOU SHOULD SEE NOW
//  - Players list breathes like LiveRoundView (row padding + divider rhythm)
//  - No swipe delete (glove-friendly)
//  - Tap a player row → menu: Edit / Delete
//  - Row also has explicit trailing "…" button (consistent with Courses/Rounds)
//  - Delete is two-step: Delete… → Confirm Delete
//  - Bottom “New Player” pill matches LiveRound primary CTA
//  - Player editor sheet matches LiveRound top bar + bottom pill and uses ValuePickerSheet wheel
//

import SwiftUI
import SwiftData

struct PlayersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Player.name, order: .forward) private var players: [Player]

    @State private var showingNew: Bool = false
    @State private var editingPlayer: Player? = nil

    // Row tap menu + delete confirm
    @State private var selectedPlayer: Player? = nil
    @State private var showRowMenu: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                    NotesScreenTitle("Players", subtitle: "Add • Edit • Delete")

                    if players.isEmpty {
                        emptyState
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.top, 8)
                    } else {
                        GSPListBlock {
                            VStack(spacing: 0) {
                                ForEach(players) { p in
                                    playerRow(p)

                                    if p.id != players.last?.id {
                                        GSPDivider(leading: GSPUI.Spacing.dividerLeading)
                                    }
                                }
                            }
                        }
                    }

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
        .sheet(isPresented: $showingNew) {
            PlayerEditorSheet(existing: nil) { _ in }
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditorSheet(existing: player) { _ in }
        }

        // Tap row menu
        .confirmationDialog(
            selectedPlayer?.name ?? "Player",
            isPresented: $showRowMenu,
            titleVisibility: .visible
        ) {
            Button("Edit Player") {
                guard let p = selectedPlayer else { return }
                HapticsManager.light()
                editingPlayer = p
            }

            Button("Delete Player…", role: .destructive) {
                HapticsManager.medium()
                showDeleteConfirm = true
            }

            Button("Done", role: .cancel) { }
        } message: {
            if let p = selectedPlayer {
                Text("\(p.name)\nHandicap \(p.handicap)")
            } else {
                Text("Choose an action.")
            }
        }

        // Two-step confirm
        .confirmationDialog(
            "Delete this player?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Player", role: .destructive) {
                guard let p = selectedPlayer else { return }
                deletePlayer(p)
                selectedPlayer = nil
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the player from your library. Past rounds won’t be affected.")
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

    // MARK: - Bottom pill

    private var bottomPill: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25)

            Button {
                HapticsManager.light()
                showingNew = true
            } label: {
                GSPPrimaryPill(title: "New Player", accent: .accentColor)
                    .padding(.horizontal, GSPUI.Spacing.insetX)
                    .padding(.top, GSPUI.Spacing.stripVPad)
                    .padding(.bottom, GSPUI.Spacing.holeRowVPad)
            }
            .buttonStyle(.plain)
        }
        .background(NotesTheme.bg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No players yet")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)

            Text("You can add players here, or add them during Round Setup.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(NotesTheme.textSecondary)
        }
        .padding(GSPUI.Spacing.cardPad)
        .notesCard()
    }

    // MARK: - Row

    private func openMenu(for player: Player) {
        HapticsManager.light()
        selectedPlayer = player
        showRowMenu = true
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {

            // Restrained "avatar language" (same column width as LiveRound)
            GSPAvatarCircle(
                initials: initials(for: player.name),
                size: GSPUI.Size.avatar,
                fill: Color.white.opacity(0.14)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(GSPUI.Typography.title3Semibold)
                    .lineLimit(1)

                Text("Handicap \(player.handicap)")
                    .foregroundStyle(NotesTheme.textSecondary)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Explicit menu target (matches Courses/Rounds; glove friendly)
            Button {
                openMenu(for: player)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.vertical, GSPUI.Spacing.rowVPad)
        .contentShape(Rectangle())
        .onTapGesture {
            // Per your spec: tap row opens the menu
            openMenu(for: player)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        if parts.isEmpty { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(2)).uppercased() }

        let first = parts.first?.prefix(1) ?? ""
        let last = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Delete

    private func deletePlayer(_ p: Player) {
        context.delete(p)
        try? context.save()
        HapticsManager.success()
    }
}

//
// MARK: - PlayerEditorSheet
// LiveRoundView UI Source of Truth (Handicap uses ValuePickerSheet wheel)
//

private struct PlayerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existing: Player?
    var onSave: (Player) -> Void = { _ in }

    @State private var name: String = ""
    @State private var handicap: Int = 0
    @State private var isSaving: Bool = false

    // Wheel picker (matches RoundSetupView)
    @State private var showHandicapPicker: Bool = false
    @State private var handicapPickerValue: Int = 0
    private let maxHandicapIndex: Int = 54

    private var accent: Color { .accentColor }

    init(existing: Player? = nil, onSave: @escaping (Player) -> Void = { _ in }) {
        self.existing = existing
        self.onSave = onSave
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                    NotesScreenTitle(
                        existing == nil ? "New Player" : "Edit Player",
                        subtitle: "Name & handicap"
                    )

                    // Name (dominant)
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Full name", text: $name)
                            .font(.system(size: 34, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textPrimary)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)

                        Divider().opacity(0.25)
                    }
                    .padding(.horizontal, GSPUI.Spacing.insetX)
                    .padding(.top, 2)

                    // Handicap row (tap → wheel picker)
                    VStack(spacing: 0) {
                        Button {
                            HapticsManager.light()
                            handicapPickerValue = handicap
                            showHandicapPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Handicap")
                                        .font(.system(size: 20, weight: .semibold, design: .default))
                                        .foregroundStyle(NotesTheme.textPrimary)

                                    Text("Tap to adjust")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundStyle(NotesTheme.textSecondary)
                                }

                                Spacer()

                                Text("\(handicap)")
                                    .font(.system(size: 28, weight: .semibold, design: .default))
                                    .foregroundStyle(NotesTheme.textPrimary)
                                    .monospacedDigit()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: GSPUI.Size.chevron, weight: .semibold, design: .default))
                                    .foregroundStyle(NotesTheme.textTertiary)
                            }
                            .padding(.vertical, GSPUI.Spacing.rowVPad)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().opacity(0.25)
                    }
                    .padding(.horizontal, GSPUI.Spacing.insetX)

                    Spacer(minLength: 28)
                        .padding(.bottom, 110)
                }
                .padding(.top, GSPUI.Spacing.pageTop)
            }
            .notesBackground()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { topBar }

            bottomPill
        }
        .onAppear { hydrate() }
        .sheet(isPresented: $showHandicapPicker) {
            ValuePickerSheet(
                title: "Handicap",
                value: $handicapPickerValue,
                range: 0...maxHandicapIndex
            )
            .onDisappear { handicap = handicapPickerValue }
        }
    }

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

    private var bottomPill: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25)

            Button {
                saveAndDismiss()
            } label: {
                GSPPrimaryPill(
                    title: existing == nil ? "Save Player" : "Save Changes",
                    accent: accent
                )
                .opacity((canSave && !isSaving) ? 1.0 : 0.45)
                .padding(.horizontal, GSPUI.Spacing.insetX)
                .padding(.top, GSPUI.Spacing.stripVPad)
                .padding(.bottom, GSPUI.Spacing.holeRowVPad)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canSave && !isSaving)
        }
        .background(NotesTheme.bg)
    }

    private func hydrate() {
        if let p = existing {
            name = p.name
            handicap = p.handicap
        } else {
            name = ""
            handicap = 0
        }
        handicapPickerValue = handicap
    }

    private func saveAndDismiss() {
        guard !isSaving else { return }
        isSaving = true

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isSaving = false; return }

        if let p = existing {
            p.name = trimmed
            p.handicap = handicap
            do { try context.save(); onSave(p) }
            catch { print("Player update save failed: \(error)"); isSaving = false; return }
        } else {
            let new = Player(name: trimmed, handicap: handicap)
            context.insert(new)
            do { try context.save(); onSave(new) }
            catch { print("Player create save failed: \(error)"); isSaving = false; return }
        }

        HapticsManager.success()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            dismiss()
        }
    }
}
