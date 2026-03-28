import SwiftUI
import SwiftData
import Foundation

//
//  LeaderboardView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25 17:XX PT (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - Standings screen matches LiveRoundView spacing + row rhythm
//  - Top bar uses GSPIconPillButton (canonical)
//  - Standings list uses GSPListBlock + GSPDivider (canonical)
//  - No swipe gestures required; menu actions live under top-right “…”
//  - Gross/Net toggle stays glove-friendly and consistent
//  - Finish Round flow is deliberate + premium (two-step confirm + optional add-to-library)
//

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var round: Round

    enum Mode: String, CaseIterable {
        case gross = "Gross"
        case net   = "Net"
    }

    @State private var mode: Mode = .gross

    @State private var rows: [LeaderboardRow] = []
    @State private var thruHole: Int = 0
    @State private var isRefreshing = false

    // Match play summary (nil for stroke play / skins rounds)
    @State private var matchSummary: MatchSummary? = nil
    @State private var matchRows: [TeamMatchRow] = []

    @State private var showMenu = false

    // ✅ Premium finish flow (two-step)
    @State private var showFinishConfirm = false

    // MARK: - Hole details expand/collapse state
    @State private var expandedHoles: Set<Int> = []
    @State private var isAllExpanded: Bool = false

    private var accent: Color { .accentColor }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                NotesScreenTitle(titleText, subtitle: subtitleText)

                modeToggle
                    .padding(.top, 2)

                if round.gameType != .strokePlay {
                    gamePlaceholderSection
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, 6)
                }

                if rows.isEmpty {
                    emptyState
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.top, 2)
                } else {
                    GSPListBlock {
                        VStack(spacing: 0) {
                            ForEach(sortedRows) { r in
                                standingsRow(r)

                                if r.id != sortedRows.last?.id {
                                    GSPDivider(leading: GSPUI.Spacing.dividerLeading)
                                }
                            }
                        }
                    }
                }

                if thruHole > 0 {
                    holeDetailsSection
                        .padding(.top, 6)

                    playerStatsSection
                        .padding(.top, 6)
                }

                Spacer(minLength: 28)
                    .padding(.bottom, 24)
            }
            .padding(.top, GSPUI.Spacing.pageTop)
        }
        .notesBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) { topBar }
        .task {
            hydrateModeFromStorage()
            rebuildSnapshot()
        }
        // ✅ High ROI: if scores change, refresh standings automatically
        .onChange(of: round.scores.count) { _ in
            rebuildSnapshot()
        }

        // Top-right menu
        .confirmationDialog("Standings", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Refresh Standings") {
                HapticsManager.light()
                rebuildSnapshot()
            }

            Button("Share Results") {
                HapticsManager.light()
                RoundSummaryCard.share(round: round)
            }

            if isFullyPosted {
                // ✅ Step 1: Finish… opens confirm dialog
                Button("Finish Round…", role: .destructive) {
                    HapticsManager.medium()
                    showFinishConfirm = true
                }
            }

            Button("Done", role: .cancel) { }
        } message: {
            if isFullyPosted {
                Text("Finish will lock this round (read-only).")
            }
        }

        // ✅ Step 2: explicit confirm (premium / glove-friendly)
        .confirmationDialog("Finish this round?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Finish Round", role: .destructive) {
                HapticsManager.medium()
                attemptFinishFromLeaderboard()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This round will be signed off and cannot be edited.")
        }
    }

    // MARK: - Title + Subtitle

    private var titleText: String {
        // If nothing posted yet, “Standings” reads better than “Thru 1”
        if thruHole <= 0 { return "Standings" }
        return "Standings Thru \(thruHole)"
    }

    private var subtitleText: String {
        let gameLabel = round.gameType.displayName
        let hcpLabel  = round.useHandicaps ? "HCP On" : "HCP Off"

        if round.gameType == .strokePlay {
            return "\(round.courseName) • \(gameLabel)"
        } else {
            return "\(round.courseName) • \(gameLabel) • \(hcpLabel)"
        }
    }

    // MARK: - Top bar (canonical)

    private var topBar: some View {
        HStack {
            GSPIconPillButton(systemName: "chevron.left") {
                HapticsManager.light()
                dismiss()
            }

            Spacer()

            if round.status == .inProgress {
                GSPIconPillButton(systemName: "ellipsis") {
                    HapticsManager.light()
                    showMenu = true
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, GSPUI.Spacing.insetTopBarTop)
        .padding(.bottom, GSPUI.Spacing.insetTopBarBottom)
        .background(NotesTheme.bg)
    }

    // MARK: - Toggle (Gross / Net)

    private var modeToggle: some View {
        HStack(spacing: 10) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    HapticsManager.light()
                    mode = m
                    rebuildSnapshot()
                } label: {
                    Text(m.rawValue)
                        .foregroundStyle(mode == m ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                        .font(.system(.headline, design: .default).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(mode == m ? 0.16 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(NotesTheme.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(m == .net && !round.useHandicaps)
                .opacity((m == .net && !round.useHandicaps) ? 0.45 : 1.0)
            }
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
    }

    private func hydrateModeFromStorage() {
        // Default: Net when handicaps are on, Gross when handicaps are off.
        // Mode is not persisted — each session starts from this deterministic default.
        mode = round.useHandicaps ? .net : .gross
    }

    // MARK: - Row UI (canonical rhythm)

    private func standingsRow(_ r: LeaderboardRow) -> some View {
        let bigTotal = (mode == .gross) ? r.grossTotal : r.netTotal
        let bigDelta = (mode == .gross) ? r.grossDelta : r.netDelta

        let dText  = deltaText(bigDelta)
        let dColor = deltaColor(bigDelta)

        return HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {

            GSPAvatarCircle(
                initials: initials(for: r.name),
                size: GSPUI.Size.avatar,
                fill: avatarFillColor(forRowID: r.id)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(r.name)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(GSPUI.Typography.title3Semibold)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(dText)
                        .foregroundStyle(dColor)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .monospacedDigit()

                    Text(mode == .gross ? "vs Par" : "Net vs Par")
                        .foregroundStyle(NotesTheme.textTertiary)
                        .font(.system(.body, design: .default))
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(bigTotal)")
                .foregroundStyle(NotesTheme.textPrimary)
                .font(GSPUI.Typography.score)
                .monospacedDigit()
        }
        .padding(.vertical, GSPUI.Spacing.rowVPad)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(r.name), \(dText), total \(bigTotal)")
    }

    private func avatarFillColor(forRowID id: UUID) -> Color {
        guard round.teamPlay else { return Color.white.opacity(0.14) }
        guard let p = round.players.first(where: { $0.id == id }) else { return Color.white.opacity(0.14) }

        switch p.team {
        case .a: return accent
        case .b: return Color.secondary.opacity(0.30)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        if parts.isEmpty { return "" }
        if parts.count == 1 { return String(parts[0].prefix(2)).uppercased() }

        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Game section (match play / skins / fallback placeholder)

    private var gamePlaceholderSection: some View {
        Group {
            if round.gameType == .matchPlay && round.teamPlay && !matchRows.isEmpty {
                matchPlaySection
            } else if round.gameType == .skins {
                skinsSection
            } else {
                genericGamePlaceholder
            }
        }
    }

    // Real match play section using NetBetterBallEngine output.
    private var matchPlaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Match Play")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title3, design: .default).weight(.semibold))

                Spacer()

                if let summary = matchSummary {
                    Text(summary.status.statusText)
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.body, design: .default).weight(.semibold))
                }
            }

            if let summary = matchSummary, summary.status.isDormie {
                Text("Dormie — match cannot be halved")
                    .foregroundStyle(NotesTheme.textSecondary)
                    .font(.system(.footnote, design: .default))
            }

            VStack(spacing: 0) {
                ForEach(matchRows) { row in
                    matchTeamRow(row)

                    if row.id != matchRows.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.10))
                            .padding(.leading, GSPUI.Spacing.insetX)
                    }
                }
            }
        }
        .padding(GSPUI.Spacing.cardPad)
        .background(NotesTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
    }

    private func matchTeamRow(_ row: TeamMatchRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.teamLabel)
                    .foregroundStyle(row.isLeading ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                    .font(.system(.title3, design: .default).weight(.semibold))
                    .lineLimit(1)

                Text(row.playerNames.joined(separator: " & "))
                    .foregroundStyle(NotesTheme.textTertiary)
                    .font(.system(.caption, design: .default))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(row.statusText)
                    .foregroundStyle(row.isLeading ? Color.green.opacity(0.8) : NotesTheme.textSecondary)
                    .font(.system(.body, design: .default).weight(.semibold))
                    .monospacedDigit()

                Text("\(row.holesWon) hole\(row.holesWon == 1 ? "" : "s") won")
                    .foregroundStyle(NotesTheme.textTertiary)
                    .font(.system(.caption, design: .default))
            }
        }
        .padding(.vertical, GSPUI.Spacing.holeRowVPad)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Skins section

    private var skinsSection: some View {
        let input = RoundInput(from: round)
        let summary = SkinsEngine.compute(input)
        let skinsRows = SkinsEngine.skinsRows(summary: summary, players: input.players)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Skins")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title3, design: .default).weight(.semibold))

                Spacer()

                if let carry = summary?.pendingCarry, carry > 0 {
                    Text("\(carry) carry")
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.body, design: .default).weight(.semibold))
                }
            }

            VStack(spacing: 0) {
                ForEach(skinsRows) { row in
                    skinsPlayerRow(row)

                    if row.id != skinsRows.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.10))
                            .padding(.leading, GSPUI.Spacing.insetX)
                    }
                }
            }
        }
        .padding(GSPUI.Spacing.cardPad)
        .background(NotesTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
    }

    private func skinsPlayerRow(_ row: SkinsRow) -> some View {
        HStack(spacing: 12) {
            Text(row.name)
                .foregroundStyle(row.skinsWon > 0 ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                .font(.system(.title3, design: .default).weight(.semibold))
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(row.skinsWon)")
                    .foregroundStyle(row.skinsWon > 0 ? Color.green.opacity(0.8) : NotesTheme.textTertiary)
                    .font(.system(.title3, design: .default).weight(.bold))
                    .monospacedDigit()

                Text(row.skinsWon == 1 ? "skin" : "skins")
                    .foregroundStyle(NotesTheme.textTertiary)
                    .font(.system(.caption, design: .default))
            }
        }
        .padding(.vertical, GSPUI.Spacing.holeRowVPad)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // Fallback: match play without team assignment
    private var genericGamePlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Standings")
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title3, design: .default).weight(.semibold))

            Text(genericPlaceholderSubtitle)
                .foregroundStyle(NotesTheme.textSecondary)
                .font(.system(.body, design: .default))

            VStack(spacing: 0) {
                ForEach(round.players, id: \.id) { p in
                    genericPlaceholderRow(for: p)

                    if p.id != round.players.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.10))
                            .padding(.leading, GSPUI.Spacing.insetX)
                    }
                }
            }
        }
        .padding(GSPUI.Spacing.cardPad)
        .background(NotesTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
    }

    private var genericPlaceholderSubtitle: String {
        switch round.gameType {
        case .matchPlay:  return "Match scoring requires team play to be enabled."
        case .skins:      return ""
        case .strokePlay: return ""
        }
    }

    private func genericPlaceholderRow(for player: Player) -> some View {
        let rightLabel: String
        let rightValue: String

        switch round.gameType {
        case .matchPlay:
            rightLabel = "Holes Won"
            rightValue = "—"
        case .skins, .strokePlay:
            rightLabel = ""
            rightValue = ""
        }

        return HStack(spacing: 12) {
            Text(player.name)
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title3, design: .default).weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(rightLabel)
                .foregroundStyle(NotesTheme.textTertiary)
                .font(.system(.body, design: .default).weight(.semibold))

            Text(rightValue)
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title3, design: .default).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, GSPUI.Spacing.holeRowVPad)
        .padding(.horizontal, GSPUI.Spacing.cardPad)
        .contentShape(Rectangle())
    }

    // MARK: - Hole Details Section

    private var holeDetailsSection: some View {
        let input = RoundInput(from: round)
        let skinsSummary = round.gameType == .skins ? SkinsEngine.compute(input) : nil

        return VStack(alignment: .leading, spacing: 0) {

            // Section header
            HStack {
                Text("Hole Details")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title3, design: .default).weight(.semibold))

                Spacer()

                Button {
                    HapticsManager.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isAllExpanded {
                            expandedHoles.removeAll()
                            isAllExpanded = false
                        } else {
                            expandedHoles = Set(1...thruHole)
                            isAllExpanded = true
                        }
                    }
                } label: {
                    Text(isAllExpanded ? "Collapse All" : "Expand All")
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default).weight(.medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.bottom, 8)

            // One collapsible row per scored hole
            VStack(spacing: 0) {
                ForEach(1...max(1, thruHole), id: \.self) { hole in
                    if hole <= thruHole {
                        holeDetailRow(hole: hole, input: input, skinsSummary: skinsSummary)

                        if hole < thruHole {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, GSPUI.Spacing.insetX)
                        }
                    }
                }
            }
            .background(NotesTheme.cardStrong)
            .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                    .strokeBorder(NotesTheme.divider, lineWidth: 1)
            )
            .padding(.horizontal, GSPUI.Spacing.insetX)
        }
        .onChange(of: thruHole) {
            // If all were expanded, keep them in sync with newly posted holes
            if isAllExpanded {
                expandedHoles = Set(1...thruHole)
            }
        }
    }

    private func holeDetailRow(hole: Int, input: RoundInput, skinsSummary: SkinsSummary?) -> some View {
        let par = input.course.par(for: hole)
        let si  = input.course.strokeIndex(for: hole)
        let isExpanded = expandedHoles.contains(hole)

        return VStack(spacing: 0) {
            // Collapsed header — always visible
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotesTheme.textTertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(hole)")
                        .foregroundStyle(NotesTheme.textPrimary)
                        .font(.system(.body, design: .default).weight(.bold))

                    Text("Par \(par) • SI \(si)")
                        .foregroundStyle(NotesTheme.textTertiary)
                        .font(.system(.caption, design: .default))
                }

                Spacer()

                // Game-specific summary text in collapsed state
                holeCollapsedBadge(hole: hole, input: input, skinsSummary: skinsSummary)
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.vertical, GSPUI.Spacing.stripVPad)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticsManager.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedHoles.remove(hole)
                    } else {
                        expandedHoles.insert(hole)
                    }
                    // Keep isAllExpanded in sync
                    isAllExpanded = expandedHoles.count == thruHole
                }
            }

            // Expanded detail — only shown when expanded
            if isExpanded {
                holeExpandedDetail(hole: hole, par: par, input: input, skinsSummary: skinsSummary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // Small trailing badge visible while the row is collapsed
    @ViewBuilder
    private func holeCollapsedBadge(hole: Int, input: RoundInput, skinsSummary: SkinsSummary?) -> some View {
        switch round.gameType {
        case .skins:
            if let outcome = skinsSummary?.holeOutcomes.first(where: { $0.holeNumber == hole }) {
                if let winnerID = outcome.winner,
                   let player = input.players.first(where: { $0.id == winnerID }) {
                    let first = player.name.components(separatedBy: " ").first ?? player.name
                    Text("\(first) +\(outcome.skinsWon)")
                        .foregroundStyle(Color.green.opacity(0.75))
                        .font(.system(.caption, design: .default).weight(.semibold))
                        .monospacedDigit()
                } else if outcome.carryOut > 0 {
                    Text("Carry \(outcome.carryOut)")
                        .foregroundStyle(NotesTheme.textTertiary)
                        .font(.system(.caption, design: .default))
                }
            }
        case .matchPlay:
            if let outcome = matchSummary?.holeOutcomes.first(where: { $0.holeNumber == hole }) {
                let label: String = {
                    switch outcome.runningStatus {
                    case .allSquare: return "AS"
                    case .leading(let side, let by, _): return "\(side.label) \(by)↑"
                    case .won(_, let r): return r
                    case .halved: return "Halved"
                    }
                }()
                Text(label)
                    .foregroundStyle(NotesTheme.textTertiary)
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
        case .strokePlay:
            if let label = strokePlayHoleBadgeLabel(hole: hole, input: input) {
                Text(label)
                    .foregroundStyle(NotesTheme.textTertiary)
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    /// Computes the compact standing label for a stroke play hole badge.
    /// Returns nil if there are no rows (shouldn't happen, but safe).
    private func strokePlayHoleBadgeLabel(hole: Int, input: RoundInput) -> String? {
        let useNet = (mode == .net)
        let builtRows = StrokePlayEngine.buildRows(for: input, through: hole)
        let sorted = builtRows.sorted {
            let lhsDelta = useNet ? $0.netDelta : $0.grossDelta
            let rhsDelta = useNet ? $1.netDelta : $1.grossDelta
            let lhsTotal = useNet ? $0.netTotal : $0.grossTotal
            let rhsTotal = useNet ? $1.netTotal : $1.grossTotal
            if lhsDelta != rhsDelta { return lhsDelta < rhsDelta }
            return lhsTotal < rhsTotal
        }
        guard let best = sorted.first else { return nil }
        let bestDelta = useNet ? best.netDelta : best.grossDelta
        let leaders   = sorted.filter { (useNet ? $0.netDelta : $0.grossDelta) == bestDelta }
        if leaders.count == sorted.count {
            return "Tied"
        } else if leaders.count == 1 {
            let first = best.name.components(separatedBy: " ").first ?? best.name
            let dText = bestDelta == 0 ? "E" : (bestDelta < 0 ? "\(bestDelta)" : "+\(bestDelta)")
            return "\(first) \(dText)"
        } else {
            let names = leaders
                .map { $0.name.components(separatedBy: " ").first ?? $0.name }
                .joined(separator: "/")
            return "\(names) tied"
        }
    }

    // Full expanded detail rows for a hole
    private func holeExpandedDetail(hole: Int, par: Int, input: RoundInput, skinsSummary: SkinsSummary?) -> some View {
        let scoreMap: [UUID: Int] = {
            var m: [UUID: Int] = [:]
            for s in input.scores where s.holeNumber == hole {
                m[s.playerID] = s.strokes
            }
            return m
        }()
        let useNet = (mode == .net) && input.useHandicaps

        return VStack(spacing: 0) {
            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(spacing: 0) {
                ForEach(input.players) { player in
                    if let gross = scoreMap[player.id] {
                        let result = StrokePlayEngine.holeResult(
                            for: player, hole: hole, strokes: gross,
                            course: input.course, useHandicaps: input.useHandicaps
                        )
                        // Result badge follows active mode
                        let activeDelta     = useNet ? result.netDelta     : result.grossDelta
                        let activeDeltaLabel = HoleLabel.from(delta: activeDelta).text
                        let activeDeltaColor = holeDetailDeltaColor(activeDelta)
                        let receivesStroke   = input.useHandicaps && result.received > 0

                        HStack(spacing: 10) {
                            // Player first name
                            Text(player.name.components(separatedBy: " ").first ?? player.name)
                                .foregroundStyle(NotesTheme.textPrimary)
                                .font(.system(.body, design: .default).weight(.medium))
                                .frame(minWidth: 60, alignment: .leading)

                            // Result label — follows active mode
                            Text(activeDeltaLabel)
                                .foregroundStyle(activeDeltaColor)
                                .font(.system(.title3, design: .default).weight(.semibold))

                            // Net indicator — shown in Gross mode when player receives a stroke,
                            // to reveal the net score without switching pills.
                            // Hidden in Net mode because the right-aligned number already shows net.
                            if receivesStroke && !useNet {
                                Text("• Net \(result.netStrokes)")
                                    .foregroundStyle(NotesTheme.textSecondary)
                                    .font(.system(.body, design: .default).weight(.regular))
                                    .monospacedDigit()
                            }

                            Spacer()

                            // Game-specific right annotation (skins win indicator, etc.)
                            holePlayerAnnotation(
                                player: player, hole: hole,
                                skinsSummary: skinsSummary
                            )

                            // Score — net strokes in Net mode, gross strokes in Gross mode
                            Text("\(useNet ? result.netStrokes : result.grossStrokes)")
                                .foregroundStyle(NotesTheme.textPrimary)
                                .font(.system(.title3, design: .default).weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .padding(.vertical, GSPUI.Spacing.holeRowVPad)
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    // Right-side annotation per player in expanded row
    @ViewBuilder
    private func holePlayerAnnotation(player: PlayerCard, hole: Int, skinsSummary: SkinsSummary?) -> some View {
        switch round.gameType {
        case .skins:
            if let outcome = skinsSummary?.holeOutcomes.first(where: { $0.holeNumber == hole }),
               outcome.winner == player.id {
                Label("\(outcome.skinsWon) skin\(outcome.skinsWon == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.green.opacity(0.75))
                    .font(.system(.caption, design: .default).weight(.semibold))
            }
        case .matchPlay:
            EmptyView()
        case .strokePlay:
            EmptyView()
        }
    }

    private func holeDetailDeltaColor(_ delta: Int) -> Color {
        if delta < 0 { return Color.green.opacity(0.75) }
        if delta > 0 { return Color.red.opacity(0.75) }
        return NotesTheme.textTertiary
    }

    // MARK: - Player Stats

    /// One card per player showing score category counts across all posted holes.
    /// Categories and colors follow the active mode (Gross or Net).
    private var playerStatsSection: some View {
        let input    = RoundInput(from: round)
        let useNet   = (mode == .net) && input.useHandicaps

        // Build score map: playerID → [holeNumber: strokes]
        let scoreMap: [UUID: [Int: Int]] = {
            var m: [UUID: [Int: Int]] = [:]
            for s in input.scores {
                m[s.playerID, default: [:]][s.holeNumber] = s.strokes
            }
            return m
        }()

        // Buckets keyed by HoleLabel — separate entry per delta value above +2
        // Returns sorted [(label, count, color)] ready for display
        func statRows(for player: PlayerCard) -> [(label: String, count: Int, color: Color)] {
            guard let holes = scoreMap[player.id], !holes.isEmpty else { return [] }

            var counts: [Int: Int] = [:]   // delta → count
            for (hole, strokes) in holes {
                let result = StrokePlayEngine.holeResult(
                    for: player, hole: hole, strokes: strokes,
                    course: input.course, useHandicaps: input.useHandicaps
                )
                let delta = useNet ? result.netDelta : result.grossDelta
                counts[delta, default: 0] += 1
            }

            // Collapse all ≤ -2 into a single EAG bucket
            var eagleCount = 0
            var remaining: [Int: Int] = [:]
            for (delta, count) in counts {
                if delta <= -2 { eagleCount += count }
                else           { remaining[delta] = count }
            }
            if eagleCount > 0 { remaining[-2] = eagleCount }  // store EAG at sentinel -2

            return remaining
                .sorted { $0.key < $1.key }
                .map { delta, count in
                    let label: String
                    let color: Color
                    switch delta {
                    case ...(-2): label = "EAG"; color = Color.green.opacity(0.75)
                    case -1:      label = "BRD"; color = Color.green.opacity(0.75)
                    case  0:      label = "PAR"; color = NotesTheme.textTertiary
                    case  1:      label = "BGY"; color = Color.red.opacity(0.75)
                    case  2:      label = "DBL"; color = Color.red.opacity(0.75)
                    default:      label = "+\(delta)"; color = Color.red.opacity(0.75)
                    }
                    return (label, count, color)
                }
        }

        let statsPerPlayer: [(player: PlayerCard, rows: [(label: String, count: Int, color: Color)])] =
            input.players.compactMap { player in
                let r = statRows(for: player)
                return r.isEmpty ? nil : (player, r)
            }

        let modeLabel = useNet ? "Net " : ""

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(modeLabel)Player Stats")
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title3, design: .default).weight(.semibold))
                .padding(.horizontal, GSPUI.Spacing.insetX)

            VStack(spacing: 0) {
                ForEach(Array(statsPerPlayer.enumerated()), id: \.element.player.id) { idx, item in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.player.name)
                            .foregroundStyle(NotesTheme.textPrimary)
                            .font(.system(.body, design: .default).weight(.semibold))
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.top, GSPUI.Spacing.holeRowVPad)
                            .padding(.bottom, 6)

                        ForEach(Array(item.rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                Text(row.label)
                                    .foregroundStyle(row.color)
                                    .font(.system(.body, design: .default).weight(.semibold))

                                Spacer(minLength: 12)

                                Text("\(row.count)")
                                    .foregroundStyle(NotesTheme.textPrimary)
                                    .font(.system(.title3, design: .default).weight(.semibold))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.vertical, 6)
                        }

                        Spacer(minLength: GSPUI.Spacing.holeRowVPad)
                    }

                    if idx < statsPerPlayer.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                            .padding(.leading, GSPUI.Spacing.insetX)
                    }
                }
            }
            .background(NotesTheme.cardStrong)
            .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                    .strokeBorder(NotesTheme.divider, lineWidth: 1)
            )
            .padding(.horizontal, GSPUI.Spacing.insetX)
        }
    }

    // MARK: - Sorting

    private var sortedRows: [LeaderboardRow] {
        switch mode {
        case .gross:
            return rows.sorted {
                if $0.grossDelta != $1.grossDelta { return $0.grossDelta < $1.grossDelta }
                if $0.grossTotal != $1.grossTotal { return $0.grossTotal < $1.grossTotal }
                return $0.name < $1.name
            }
        case .net:
            return rows.sorted {
                if $0.netDelta != $1.netDelta { return $0.netDelta < $1.netDelta }
                if $0.netTotal != $1.netTotal { return $0.netTotal < $1.netTotal }
                return $0.name < $1.name
            }
        }
    }

    // MARK: - Helpers

    private func deltaColor(_ d: Int) -> Color {
        if d < 0 { return Color.green.opacity(0.75) }
        if d > 0 { return Color.red.opacity(0.75) }
        return NotesTheme.textSecondary
    }

    private func deltaText(_ d: Int) -> String {
        if d == 0 { return "E" }
        return d < 0 ? "\(d)" : "+\(d)"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No scores yet")
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title2, design: .default).weight(.semibold))

            Text("Post a hole to see standings.")
                .foregroundStyle(NotesTheme.textSecondary)
                .font(.system(.body, design: .default))
        }
        .padding(GSPUI.Spacing.cardPad)
        .background(NotesTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
    }

    private var isFullyPosted: Bool { thruHole >= round.totalHoles }

    // MARK: - Finish round

    private func attemptFinishFromLeaderboard() {
        showFinishConfirm = false
        completeFinishToHome()
    }

    private func completeFinishToHome() {
        round.status = .completed
        try? context.save()
        HapticsManager.success()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            NotificationCenter.default.post(name: .gspDismissToHomeFromFinishRound, object: nil)
            dismiss()
        }
    }

    // MARK: - Snapshot build

    private func rebuildSnapshot() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let input = RoundInput(from: round)
        thruHole = StrokePlayEngine.computeThruHole(input)
        rows = StrokePlayEngine.buildRows(for: input, through: thruHole)

        if round.gameType == .matchPlay && round.teamPlay {
            let summary = NetBetterBallEngine.compute(input)
            matchSummary = summary
            matchRows = NetBetterBallEngine.teamMatchRows(summary: summary, players: input.players)
        } else {
            matchSummary = nil
            matchRows = []
        }
    }
}



