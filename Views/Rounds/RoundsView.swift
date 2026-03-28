//
//  RoundsView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25 (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - Same breathing + row rhythm as LiveRoundView
//  - Same top-bar icon pill as LiveRoundView
//  - NO swipe-to-delete (glove-friendly)
//  - Each row has an explicit trailing "…" menu → Delete Round (two-step)
//  - Tap row: completed → Leaderboard (read-only), inProgress → LiveRound
//

import SwiftUI
import SwiftData

struct RoundsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Round.createdAt, order: .reverse) private var rounds: [Round]

    // Navigation
    @State private var navRound: Round? = nil

    // Row menu
    @State private var menuRound: Round? = nil
    @State private var showRowMenu: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                NotesScreenTitle("Rounds", subtitle: "View • Delete")

                if rounds.isEmpty {
                    emptyState
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, 2)
                } else {
                    GSPListBlock {
                        VStack(spacing: 0) {
                            ForEach(rounds) { r in
                                RoundRow(
                                    round: r,
                                    onOpen: {
                                        HapticsManager.light()
                                        navRound = r
                                    },
                                    onMenu: {
                                        HapticsManager.light()
                                        menuRound = r
                                        showRowMenu = true
                                    }
                                )

                                if r.id != rounds.last?.id {
                                    GSPDivider(leading: GSPUI.Spacing.dividerLeading)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 28)
            }
            .padding(.top, GSPUI.Spacing.pageTop)
        }
        .notesBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) { topBar }

        // Navigation (clean + glove-safe)
        .navigationDestination(item: $navRound) { r in
            if r.status == .completed {
                LeaderboardView(round: r)
            } else {
                LiveRoundView(round: r)
            }
        }

        // Step 1: Row menu
        .confirmationDialog(
            "Round",
            isPresented: $showRowMenu,
            titleVisibility: .visible
        ) {
            Button("Delete Round…", role: .destructive) {
                HapticsManager.medium()
                showDeleteConfirm = true
            }

            Button("Done", role: .cancel) {
                menuRound = nil
            }
        } message: {
            if let r = menuRound {
                Text(menuMessage(for: r))
            }
        }

        // Step 2: Confirm delete (GolfScorePro standard)
        .confirmationDialog(
            "Delete this round?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Round", role: .destructive) {
                if let r = menuRound {
                    deleteRound(r)
                }
                menuRound = nil
            }

            Button("Keep Round", role: .cancel) { }
        } message: {
            Text("This can’t be undone.")
        }
    }

    // MARK: - Top bar (LiveRound canonical)

    private var topBar: some View {
        HStack {
            GSPIconPillButton(systemName: "chevron.left") {
                HapticsManager.light()
                dismiss()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, GSPUI.Spacing.insetTopBarTop)
        .padding(.bottom, GSPUI.Spacing.insetTopBarBottom)
        .background(NotesTheme.bg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(NotesTheme.textTertiary)

            Text("No Rounds Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NotesTheme.textPrimary)

            Text("Start a round from the home screen.")
                .font(.subheadline)
                .foregroundStyle(NotesTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Delete

    private func deleteRound(_ r: Round) {
        // If you ever want to be explicit:
        // for s in r.scores { context.delete(s) }

        context.delete(r)
        try? context.save()
        HapticsManager.success()

        menuRound = nil
        showRowMenu = false
        showDeleteConfirm = false
    }

    private func menuMessage(for r: Round) -> String {
        let statusText = (r.status == .completed) ? "Completed" : "In Progress"
        return "\(r.courseName)\n\(statusText) • Hole \(r.currentHole) of \(r.totalHoles)"
    }
}

// MARK: - Row (LiveRound rhythm + explicit menu)

private struct RoundRow: View {
    let round: Round
    let onOpen: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {

            // Main tap target (separate from menu button = no gesture conflicts)
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {

                    Image(systemName: "flag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotesTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(NotesTheme.accentSoft))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.courseName)
                            .foregroundStyle(NotesTheme.textPrimary)
                            .font(.system(.title3, design: .default).weight(.semibold))
                            .lineLimit(1)

                        Text("Hole \(round.currentHole) • \(round.totalHoles) holes")
                            .foregroundStyle(NotesTheme.textSecondary)
                            .font(.system(.body, design: .default))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    StatusTag(status: round.status)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Explicit menu target (glove friendly)
            Button(action: onMenu) {
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
    }

}

private struct StatusTag: View {
    let status: RoundStatus

    var body: some View {
        let isLive = (status != .completed)

        Text(isLive ? "LIVE" : "DONE")
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(isLive ? NotesTheme.textPrimary : NotesTheme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isLive ? 0.12 : 0.08))
            )
    }
}
