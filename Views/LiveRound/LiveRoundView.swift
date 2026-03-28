import SwiftUI
import SwiftData
import Foundation

struct LiveRoundView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var round: Round

    @State private var strokesForHole: [UUID: Int] = [:]
    @State private var pickerPlayer: Player? = nil
    @State private var showFinishModal = false

    @State private var showToast = false
    @State private var toastMessage: String = ""

    @State private var goToLeaderboard = false

    @State private var isHoleNavLocked = false
    @State private var navTask: Task<Void, Never>?

    @State private var showMenu = false
    @State private var showCancelConfirm = false

    @State private var showJumpSheet = false
    @State private var jumpHole: Int = 1

    @State private var showRoundCompleteSheet = false

    @State private var thruHole: Int = 0

    // ✅ Header post state
    private enum HolePostState { case pending, posted }
    @State private var holePostState: HolePostState = .pending

    private var currentPar: Int { round.parForHole(round.currentHole) }
    private var currentSI: Int { round.strokeIndexForHole(round.currentHole) }

    private var accent: Color { Color.accentColor }

    private var headerSubtitle: String {
        let status = (holePostState == .posted) ? "Posted" : "Post Pending"
        return "\(round.courseName) • Par \(currentPar) • SI \(currentSI) • \(status)"
    }

    // ✅ Back behavior: allow going back to RoundSetup only if nothing has been posted yet.
    private var canBackToSetup: Bool {
        !(round.currentHole == 1 && thruHole > 0)
    }

    private var isLastHole: Bool { round.currentHole >= round.totalHoles }

    var body: some View {
        ZStack {
            content
                .notesBackground()
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top) { topBar }

            toastLayer

            if showFinishModal { finishOverlay }
        }
        .sheet(item: $pickerPlayer) { player in
            ValuePickerSheet(
                title: "\(player.name) • Hole \(round.currentHole)",
                value: bindingFor(player: player),
                range: 1...15
            )
        }
        .sheet(isPresented: $showJumpSheet) { jumpToHoleSheet }
        .sheet(isPresented: $showRoundCompleteSheet) { roundCompleteSheet }
        .confirmationDialog("Round", isPresented: $showMenu, titleVisibility: .visible) {
            // unchanged
            Button("Standings") {
                HapticsManager.light()
                recalcThruHole()
                goToLeaderboard = true
            }
            Button("Refresh") {
                HapticsManager.light()
                loadScoresForCurrentHole()
                recalcPostState()
            }
            Button("Jump to Hole") {
                HapticsManager.light()
                jumpHole = max(1, min(round.totalHoles, round.currentHole))
                showJumpSheet = true
            }
            Button("Pause Round") {
                HapticsManager.light()
                NotificationCenter.default.post(name: .gspDismissToHomeFromFinishRound, object: nil)
            }
            Button("Cancel Round", role: .destructive) {
                HapticsManager.medium()
                showCancelConfirm = true
            }
            if thruHole >= round.totalHoles {
                Button("Finish Round", role: .destructive) {
                    HapticsManager.medium()
                    attemptFinishRound()
                }
            }
            Button("Done", role: .cancel) { }
        }
        .alert("Cancel this round?", isPresented: $showCancelConfirm) {
            Button("Cancel Round", role: .destructive) { cancelRoundAndExit() }
            Button("Keep Round", role: .cancel) { }
        } message: {
            Text("This will delete all scores for this round.")
        }
        .task {
            loadScoresForCurrentHole()
            recalcThruHole()
            recalcPostState()
        }
        .onChange(of: round.currentHole) {
            loadScoresForCurrentHole()
            recalcThruHole()
            recalcPostState()
        }
        .onChange(of: strokesForHole) {
            recalcPostState()
        }
        .navigationDestination(isPresented: $goToLeaderboard) {
            LeaderboardView(round: round)
        }
    }

    // MARK: - BODY ENDS - PRE-CLAUDE new BODY 3/2/26
    
    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // No back chevron during active scoring — use Pause Round or Cancel Round
            // from the "..." menu to exit. LeaderboardView has its own chevron unaffected.
            Spacer()

            NotesIconPillButton(systemName: "ellipsis") {
                HapticsManager.light()
                recalcThruHole()
                showMenu = true
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(NotesTheme.bg)
    }

    // MARK: - Hole Hero Header

    private var holeHero: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HOLE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NotesTheme.textTertiary)
                    .kerning(1)
                Text("\(round.currentHole)")
                    .font(.system(size: 72, weight: .black, design: .default))
                    .foregroundStyle(NotesTheme.textPrimary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 8) {
                holeChip(value: "\(currentPar)", label: "Par")
                holeChip(value: "\(currentSI)", label: "SI")
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, 4)
    }

    private func holeChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(NotesTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NotesTheme.textTertiary)
        }
        .frame(width: 48, height: 48)
        .notesCard(cornerRadius: 12)
    }

    private var holeCourseLabel: some View {
        Text(round.courseName)
            .font(.caption)
            .foregroundStyle(NotesTheme.textTertiary)
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.bottom, 2)
    }

    // MARK: - Player Row (Net only if strokes received)

    private func playerRow(_ player: Player) -> some View {
        let strokes = strokesForHole[player.id] ?? currentPar
        let grossDelta = strokes - currentPar

        let received = strokesReceivedThisHole(for: player)
        let netStrokes = max(1, strokes - received)

        let netPar = max(1, currentPar - received)
        let netDelta = netStrokes - netPar

        let label = resultLabel(for: grossDelta)
        let labelColor = labelColor(forNetDelta: netDelta)

        return Button {
            HapticsManager.light()
            pickerPlayer = player
        } label: {
            HStack(alignment: .center, spacing: 14) {

                AvatarCircle(
                    initials: initials(for: player.name),
                    size: 56,
                    fill: avatarFillColor(for: player)
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(label)
                            .foregroundStyle(labelColor)
                            .font(.system(.title3, design: .default).weight(.semibold))

                        if received > 0 {
                            Text("Net \(netStrokes)")
                                .foregroundStyle(NotesTheme.textSecondary)
                                .font(.system(.subheadline, design: .default))
                                .monospacedDigit()
                        }
                    }

                    if let total = runningTotal(for: player) {
                        Text(total)
                            .font(.caption)
                            .foregroundStyle(NotesTheme.textSecondary)
                            .monospacedDigit()
                    }
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(strokes)")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(size: 38, weight: .semibold, design: .default))
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(NotesTheme.divider, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private struct AvatarCircle: View {
        let initials: String
        let size: CGFloat
        let fill: Color

        var body: some View {
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .default))
                .foregroundStyle(Color.white.opacity(0.92))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(fill)
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 8)
                )
        }
    }


    private func avatarFillColor(for player: Player) -> Color {
        guard round.teamPlay else { return Color.white.opacity(0.14) }
        switch player.team {
        case .a: return accent
        case .b: return Color.secondary.opacity(0.30)
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

    private func labelColor(forNetDelta d: Int) -> Color {
        if d < 0 { return Color.green.opacity(0.75) }
        if d > 0 { return Color.red.opacity(0.75) }
        return NotesTheme.textSecondary
    }

    private func runningTotal(for player: Player) -> String? {
        let posted = round.scores.filter {
            $0.player.id == player.id && $0.holeNumber < round.currentHole
        }
        guard !posted.isEmpty else { return nil }
        let totalStrokes = posted.reduce(0) { $0 + $1.strokes }
        let totalPar = posted.map(\.holeNumber).reduce(0) { $0 + round.parForHole($1) }
        let delta = totalStrokes - totalPar
        let deltaStr = delta == 0 ? "E" : (delta < 0 ? "\(delta)" : "+\(delta)")
        return "\(deltaStr) thru \(posted.count)"
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 14) {

            NotesIconPillButton(systemName: "chevron.left") { navigateHole(delta: -1) }
                .frame(width: 58, height: 58)
                .disabled(isHoleNavLocked || round.currentHole <= 1)
                .opacity((isHoleNavLocked || round.currentHole <= 1) ? 0.35 : 1.0)

            primaryActionPill

            NotesIconPillButton(systemName: "chevron.right") {
                if isLastHole {
                    HapticsManager.medium()
                    showFinishModal = true
                } else {
                    HapticsManager.medium()
                    navigateHole(delta: 1)
                }
            }
            .frame(width: 58, height: 58)
            .disabled(isHoleNavLocked)
            .opacity(isHoleNavLocked ? 0.60 : 1.0)
        }
        .padding(.bottom, 12)
    }

    private var primaryActionPill: some View {
        Button {
            if holePostState == .posted {
                // ✅ Next Hole behavior
                if isLastHole {
                    HapticsManager.medium()
                    showRoundCompleteSheet = true
                } else {
                    HapticsManager.medium()
                    navigateHole(delta: 1)
                }
                return
            }

            // ✅ Post behavior
            _ = saveScoresForCurrentHole()
            recalcThruHole()
            recalcPostState()
            HapticsManager.success()

            showToastMessage("Posted • Hole \(round.currentHole)")

            if thruHole >= round.totalHoles && round.currentHole == round.totalHoles {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    showRoundCompleteSheet = true
                }
            }
        } label: {
            Text(holePostState == .posted ? (isLastHole ? "Round Complete" : "Next Hole") : "Post")
                .foregroundStyle(.black.opacity(0.92))
                .font(.system(size: 28, weight: .semibold, design: .default))
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(accent)
                        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 12)
                )
        }
        .buttonStyle(.plain)
        .disabled(isHoleNavLocked)
        .opacity(isHoleNavLocked ? 0.60 : 1.0)
        .accessibilityLabel(holePostState == .posted ? "Next hole" : "Post hole")
    }

    // MARK: - Round Complete Sheet

    private var roundCompleteSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Round Complete")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title2, design: .default).weight(.semibold))

                Spacer()

                Button("Done") {
                    HapticsManager.light()
                    showRoundCompleteSheet = false
                }
                .foregroundStyle(accent)
                .font(.system(.headline, design: .default))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Text("All holes are posted.")
                .foregroundStyle(NotesTheme.textSecondary)
                .font(.system(.body, design: .default))
                .padding(.horizontal, 18)

            VStack(spacing: 10) {
                Button {
                    HapticsManager.medium()
                    showRoundCompleteSheet = false
                    attemptFinishRound()
                } label: {
                    Text("Finish Round")
                        .foregroundStyle(.black.opacity(0.92))
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)

                Button {
                    HapticsManager.light()
                    showRoundCompleteSheet = false
                    goToLeaderboard = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "list.number")
                            .font(.system(size: 20, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textPrimary)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("View Standings")
                                .foregroundStyle(NotesTheme.textPrimary)
                                .font(.system(.title3, design: .default).weight(.semibold))

                            Text("See final standings")
                                .foregroundStyle(NotesTheme.textSecondary)
                                .font(.system(.body, design: .default).weight(.regular))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)

                Button {
                    HapticsManager.light()
                    RoundSummaryCard.share(round: round)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textPrimary)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share Results")
                                .foregroundStyle(NotesTheme.textPrimary)
                                .font(.system(.title3, design: .default).weight(.semibold))

                            Text("Share as image")
                                .foregroundStyle(NotesTheme.textSecondary)
                                .font(.system(.body, design: .default).weight(.regular))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
            }

            Spacer(minLength: 0)
        }
        .notesBackground()
        .presentationDetents([.medium])
    }

    // MARK: - Finish overlay

    private var finishOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
                .onTapGesture {
                    showFinishModal = false
                    HapticsManager.light()
                }

            VStack(alignment: .leading, spacing: 14) {
                Text("Finish Round?")
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title2, design: .default).weight(.semibold))

                Text("You’re on the last hole. Finish now or keep editing scores.")
                    .foregroundStyle(NotesTheme.textSecondary)
                    .font(.system(.body, design: .default))

                HStack(spacing: 10) {
                    Button {
                        showFinishModal = false
                        attemptFinishRound()
                    } label: {
                        Text("Finish")
                            .foregroundStyle(.black)
                            .font(.system(.headline, design: .default))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(accent)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showFinishModal = false
                        HapticsManager.light()
                    } label: {
                        Text("Keep Scoring")
                            .foregroundStyle(NotesTheme.textPrimary)
                            .font(.system(.headline, design: .default))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .notesCard()
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Finish Round flow

    private func attemptFinishRound() {
        showFinishModal = false
        showRoundCompleteSheet = false
        completeFinishFlowToHome()
    }

    private func completeFinishFlowToHome() {
        round.status = .completed
        try? context.save()
        HapticsManager.success()

        showToastMessage("Round Posted")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            NotificationCenter.default.post(name: .gspDismissToHomeFromFinishRound, object: nil)
            dismiss()
        }
    }

    // MARK: - Cancel

    private func cancelRoundAndExit() {
        // Mark completed first so any stale @Query snapshot in HomeView never
        // sees this round as inProgress, regardless of deletion propagation timing.
        round.status = .completed
        for s in round.scores { context.delete(s) }
        context.delete(round)

        do { try context.save() }
        catch { print("Cancel round save failed: \(error)") }

        HapticsManager.success()
        NotificationCenter.default.post(name: .gspDismissToHomeFromFinishRound, object: nil)
    }

    // MARK: - Jump sheet

    private var jumpToHoleSheet: some View {
        ValuePickerSheet(
            title: "Jump to Hole",
            value: $jumpHole,
            range: 1...max(1, round.totalHoles)
        )
        .onAppear {
            jumpHole = max(1, min(round.totalHoles, round.currentHole))
        }
        .onDisappear {
            let target = max(1, min(round.totalHoles, jumpHole))
            guard target != round.currentHole else { return }
            round.currentHole = target
            try? context.save()

            loadScoresForCurrentHole()
            recalcThruHole()
            recalcPostState()
            HapticsManager.medium()
        }
    }

    // MARK: - Toast HUD

    private struct ToastHUD: View {
        let text: String
        let width: CGFloat
        let accent: Color

        var body: some View {
            Text(text)
                .foregroundStyle(.black.opacity(0.92))
                .font(.system(.headline, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: width, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(accent)
                        .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 14)
                )
        }
    }

    private func showToastMessage(_ text: String) {
        toastMessage = text
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            showToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                showToast = false
            }
        }
    }

    // MARK: - Navigation

    private func navigateHole(delta: Int) {
        guard !isHoleNavLocked else { return }
        isHoleNavLocked = true

        navTask?.cancel()
        navTask = Task { @MainActor in
            defer { isHoleNavLocked = false }

            moveHole(by: delta)
            loadScoresForCurrentHole()
            recalcThruHole()
            recalcPostState()
            HapticsManager.light()
        }
    }

    // MARK: - Bindings / data

    private func bindingFor(player: Player) -> Binding<Int> {
        Binding(
            get: { strokesForHole[player.id] ?? currentPar },
            set: { newValue in
                strokesForHole[player.id] = newValue
            }
        )
    }

    private func scoreRow(for player: Player, hole: Int) -> Score? {
        if let s = round.scores.first(where: { $0.player.id == player.id && $0.holeNumber == hole }) {
            return s
        }

        let pid = player.id
        let rid = round.id

        let desc = FetchDescriptor<Score>(
            predicate: #Predicate { s in
                s.player.id == pid && s.round.id == rid && s.holeNumber == hole
            }
        )
        return try? context.fetch(desc).first
    }

    private func loadScoresForCurrentHole() {
        guard !round.players.isEmpty else { return }
        var dict: [UUID: Int] = [:]

        for player in round.players {
            if let s = scoreRow(for: player, hole: round.currentHole) {
                dict[player.id] = s.strokes
            } else {
                dict[player.id] = currentPar
            }
        }
        strokesForHole = dict
        recalcPostState()
    }

    @discardableResult
    private func saveScoresForCurrentHole() -> Bool {
        for player in round.players {
            let strokes = strokesForHole[player.id] ?? currentPar

            if let existing = scoreRow(for: player, hole: round.currentHole) {
                existing.strokes = strokes
            } else {
                let score = Score(player: player, round: round, holeNumber: round.currentHole, strokes: strokes)
                context.insert(score)
                round.scores.append(score)
            }
        }

        do {
            try context.save()
            return true
        } catch {
            print("Error saving scores: \(error)")
            return false
        }
    }

    private func moveHole(by delta: Int) {
        let newHole = max(1, min(round.totalHoles, round.currentHole + delta))
        guard newHole != round.currentHole else { return }
        round.currentHole = newHole
        try? context.save()
    }

    // MARK: - Labels + net strokes received

    private func resultLabel(for delta: Int) -> String {
        switch delta {
        case ...(-3): return "\(delta)"
        case -2: return "EAG"
        case -1: return "BRD"
        case 0:  return "PAR"
        case 1:  return "BGY"
        case 2:  return "DBL"
        default: return "+\(delta)"
        }
    }

    private func strokesReceivedThisHole(for player: Player) -> Int {
        // When handicaps are off, no strokes are received on any hole.
        guard round.useHandicaps else { return 0 }

        // For match play team rounds, use playing handicap = differential from lowest in group.
        // For all other formats, use the player's full handicap (preserves stroke play behavior).
        let hcp: Int
        if round.gameType == .matchPlay && round.teamPlay {
            let minHcp = round.players.map(\.handicap).min() ?? 0
            hcp = max(0, player.handicap - minHcp)
        } else {
            hcp = player.handicap
        }
        guard hcp > 0 else { return 0 }

        let si = round.strokeIndexForHole(round.currentHole)
        var received = 0
        var threshold = si

        while hcp >= threshold {
            received += 1
            threshold += 18
        }
        return received
    }

    // MARK: - Thru calc

    private func recalcThruHole() { thruHole = computeThruHole() }

    private func computeThruHole() -> Int {
        guard !round.players.isEmpty else { return 0 }
        let playerIDs = Set(round.players.map { $0.id })

        var best = 0
        for h in 1...round.totalHoles {
            let scoredPlayers = Set(
                round.scores
                    .filter { $0.holeNumber == h }
                    .map { $0.player.id }
            )
            if scoredPlayers == playerIDs { best = h } else { break }
        }
        return best
    }

    // MARK: - Post state calc

    private func recalcPostState() {
        guard !round.players.isEmpty else {
            holePostState = .pending
            return
        }

        for p in round.players {
            guard let s = round.scores.first(where: { $0.player.id == p.id && $0.holeNumber == round.currentHole }) else {
                holePostState = .pending
                return
            }

            let buffer = strokesForHole[p.id] ?? currentPar
            if s.strokes != buffer {
                holePostState = .pending
                return
            }
        }

        holePostState = .posted
    }
    
    // MARK: - HELPERS ON SIZE REFACTOR - PRE-CLAUDE - 3/2/26
    
    // MARK: - Hole Context Strip (stroke receivers, compact)

    /// Single-line strip listing players who receive a handicap stroke on the current hole.
    /// Hidden when no player receives a stroke.
    @ViewBuilder
    private var holeContextStrip: some View {
        let receivers = round.players.filter { strokesReceivedThisHole(for: $0) > 0 }
        if !receivers.isEmpty {
            // Build an AttributedString: dots dimmed, names at full white
            let attributed: AttributedString = {
                var result = AttributedString()
                let names = receivers.map {
                    $0.name.components(separatedBy: " ").first ?? $0.name
                }
                for (i, name) in names.enumerated() {
                    var dot = AttributedString("●")
                    dot.foregroundColor = UIColor(white: 1, alpha: 0.38)
                    let space = AttributedString(" ")
                    var nameStr = AttributedString(name)
                    nameStr.foregroundColor = UIColor(white: 1, alpha: 1)
                    result += dot + space + nameStr
                    if i < names.count - 1 {
                        let gap = AttributedString("   ")
                        result += gap
                    }
                }
                return result
            }()

            Text(attributed)
                .font(.system(.subheadline, design: .default).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Skins Status Strip

    /// Compact live skins status strip shown for skins rounds.
    /// Hidden until at least one hole is fully posted.
    @ViewBuilder
    private var skinsStatusStrip: some View {
        if round.gameType == .skins {
            let input = RoundInput(from: round)
            let summary = SkinsEngine.compute(input)

            if let summary {
                let rows = SkinsEngine.skinsRows(summary: summary, players: input.players)
                // All players tied at the top (same skins count, ≥1)
                let maxSkins = rows.first?.skinsWon ?? 0
                let leaders = maxSkins > 0 ? rows.filter { $0.skinsWon == maxSkins } : []

                // Primary line
                let primaryText: String = {
                    guard !leaders.isEmpty else { return "No skins won yet" }
                    let names = leaders
                        .map { $0.name.components(separatedBy: " ").first ?? $0.name }
                        .joined(separator: ", ")
                    return "\(names) • Skins \(maxSkins)"
                }()

                // Secondary line
                let secondaryText: String = {
                    let carry = summary.pendingCarry
                    let thru  = summary.thruHole
                    if carry == 0 { return "No carry • Thru \(thru)" }
                    let skinWord = carry == 1 ? "skin" : "skins"
                    return "\(carry) \(skinWord) carry • Thru \(thru)"
                }()

                VStack(alignment: .leading, spacing: GSPUI.Spacing.stripLineSpacing) {
                    Text(primaryText)
                        .foregroundStyle(NotesTheme.textPrimary)
                        .font(.system(size: 26, weight: .bold, design: .default))

                    Text(secondaryText)
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticsManager.light()
                    goToLeaderboard = true
                }
                .padding(.horizontal, GSPUI.Spacing.insetX)
                .padding(.vertical, GSPUI.Spacing.stripVPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .notesCard()
                .padding(.horizontal, GSPUI.Spacing.insetX)
            }
        }
    }

    // MARK: - Stroke Play Status Strip

    /// Compact leader summary for stroke play rounds.
    /// Shows the current leader's name + score on line 1, natural-language gap on line 2.
    /// Hidden until at least one hole is fully posted (thruHole > 0).
    @ViewBuilder
    private var strokePlayStatusStrip: some View {
        if round.gameType == .strokePlay && thruHole > 0 {
            let input = RoundInput(from: round)
            let allRows = StrokePlayEngine.buildRows(for: input, through: thruHole)

            // Sort: net mode when handicaps on, gross otherwise
            let useNet = round.useHandicaps
            let sorted = allRows.sorted {
                let d0 = useNet ? $0.netDelta  : $0.grossDelta
                let d1 = useNet ? $1.netDelta  : $1.grossDelta
                let t0 = useNet ? $0.netTotal  : $0.grossTotal
                let t1 = useNet ? $1.netTotal  : $1.grossTotal
                if d0 != d1 { return d0 < d1 }
                if t0 != t1 { return t0 < t1 }
                return $0.name < $1.name
            }

            if let leader = sorted.first {
                let leaderTotal  = useNet ? leader.netTotal  : leader.grossTotal
                let leaderFirst  = leader.name.components(separatedBy: " ").first ?? leader.name

                // Secondary line: gap is second.total - leader.total (running strokes, not to-par delta)
                let secondaryLine: String = {
                    let rest = sorted.dropFirst()
                    let tiedCount = rest.filter {
                        (useNet ? $0.netTotal : $0.grossTotal) == leaderTotal
                    }.count

                    if tiedCount == 0 {
                        if let second = rest.first {
                            let secondTotal = useNet ? second.netTotal : second.grossTotal
                            let gap = secondTotal - leaderTotal   // always positive: second is behind
                            let secondFirst = second.name.components(separatedBy: " ").first ?? second.name
                            return "Leads \(secondFirst) by \(gap) • Thru \(thruHole)"
                        }
                        return "Sole leader • Thru \(thruHole)"
                    } else if tiedCount == 1 {
                        let secondFirst = rest.first?.name.components(separatedBy: " ").first ?? ""
                        return "Tied with \(secondFirst) • Thru \(thruHole)"
                    } else {
                        return "\(tiedCount + 1) players tied • Thru \(thruHole)"
                    }
                }()

                VStack(alignment: .leading, spacing: GSPUI.Spacing.stripLineSpacing) {
                    // Line 1: "Name • Score" — large, white, dominant
                    Text("\(leaderFirst) • \(useNet ? "Net \(leaderTotal)" : "\(leaderTotal)")")
                        .foregroundStyle(NotesTheme.textPrimary)
                        .font(.system(size: 26, weight: .bold, design: .default).monospacedDigit())

                    // Line 2: gap / tie summary — secondary
                    Text(secondaryLine)
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticsManager.light()
                    goToLeaderboard = true
                }
                .padding(.horizontal, GSPUI.Spacing.insetX)
                .padding(.vertical, GSPUI.Spacing.stripVPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                .notesCard()
                .padding(.horizontal, GSPUI.Spacing.insetX)
            }
        }
    }

    // MARK: - Match Status Strip (team match play only)

    /// Compact live match-status strip shown between the hole header and player list
    /// for team match play rounds. Hidden for all other game formats.
    @ViewBuilder
    private var matchStatusStrip: some View {
        if round.gameType == .matchPlay && round.teamPlay {
            let input = RoundInput(from: round)
            let summary = NetBetterBallEngine.compute(input)

            // Team name strings (first names only, joined with " & ")
            let namesA = round.players
                .filter { $0.team == .a }
                .map { $0.name.components(separatedBy: " ").first ?? $0.name }
                .joined(separator: " & ")
            let namesB = round.players
                .filter { $0.team == .b }
                .map { $0.name.components(separatedBy: " ").first ?? $0.name }
                .joined(separator: " & ")

            // Derive status text and leading team from summary
            let status = summary?.status
            let leadingSide: TeamID? = {
                guard let s = status else { return nil }
                switch s {
                case .leading(let side, _, _): return side
                case .won(let winner, _): return winner
                default: return nil
                }
            }()
            let statusText: String = {
                guard let s = status else { return "AS" }
                switch s {
                case .allSquare: return "AS"
                case .leading(_, let lead, _): return "\(lead) UP"
                case .won(_, let result): return result
                case .halved: return "Halved"
                }
            }()
            let isDormie = status?.isDormie ?? false

            HStack(alignment: .center, spacing: 0) {

                // Team A side
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team A")
                        .foregroundStyle(leadingSide == .a ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                    if !namesA.isEmpty {
                        Text(namesA)
                            .foregroundStyle(NotesTheme.textTertiary)
                            .font(.system(.caption, design: .default))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Centre: status + dormie badge
                VStack(spacing: 5) {
                    Text(statusText)
                        .foregroundStyle(NotesTheme.textPrimary)
                        .font(.system(size: 28, weight: .bold, design: .default).monospacedDigit())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if isDormie {
                        Text("DORMIE")
                            .foregroundStyle(Color.yellow.opacity(0.85))
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .tracking(1.2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.yellow.opacity(0.15))
                                    .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1))
                            )
                    }
                }
                .frame(minWidth: 80)

                // Team B side
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Team B")
                        .foregroundStyle(leadingSide == .b ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                    if !namesB.isEmpty {
                        Text(namesB)
                            .foregroundStyle(NotesTheme.textTertiary)
                            .font(.system(.caption, design: .default))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticsManager.light()
                goToLeaderboard = true
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.vertical, GSPUI.Spacing.stripVPad)
            .notesCard()
            .padding(.horizontal, GSPUI.Spacing.insetX)
        }
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                holeHero
                holeCourseLabel

                holeContextStrip

                strokePlayStatusStrip

                skinsStatusStrip

                matchStatusStrip

                playerList

                Spacer(minLength: 10)

                bottomBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)
            }
            .padding(.top, 6)
        }
    }

    private var playerList: some View {
        // In team rounds, group Team A first then Team B; preserve original order within each group.
        // In non-team rounds, preserve the original player order.
        let orderedPlayers: [Player] = {
            guard round.teamPlay else { return round.players }
            let teamA = round.players.filter { $0.team == .a }
            let teamB = round.players.filter { $0.team == .b }
            return teamA + teamB
        }()

        return VStack(spacing: 10) {
            ForEach(orderedPlayers, id: \.id) { player in
                playerRow(player)
                    .padding(.horizontal, GSPUI.Spacing.insetX)
            }
        }
    }

    private var toastLayer: some View {
        VStack {
            Spacer()
            if showToast {
                GeometryReader { geo in
                    let w = min(geo.size.width - 36, 520)
                    ToastHUD(text: toastMessage, width: w, accent: accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 120)
                .transition(.opacity)
                .padding(.bottom, 96)
            }
        }
        .allowsHitTesting(false)
    }
    
} // END OF LIVEROUNDVIEW
