import SwiftUI
import SwiftData

//
//  RoundSetupView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25 17:XX PT (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - New Round screen breathes exactly like LiveRoundView (spacing + dividers + typography rhythm)
//  - Top bar uses GSPIconPillButton (same padding + chrome as LiveRoundView)
//  - Sections (Game / Players / Course) use the same row stack + divider language as LiveRoundView
//  - Start Round is a bottom safe-area pill (canonical across the app)
//  - No swipe gestures required; everything is explicit + glove-friendly
//  - Coming-soon toast matches LiveRoundView toast style
//

struct RoundSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    // MARK: - Game config (persisted into Round)

    enum GameType: String, CaseIterable, Identifiable {
        case strokePlay = "strokePlay"
        case matchPlay  = "matchPlay"
        case skins      = "skins"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .strokePlay: return "Stroke Play"
            case .matchPlay:  return "Match Play"
            case .skins:      return "Skins"
            }
        }

        var subtitle: String {
            switch self {
            case .strokePlay: return "Total score wins."
            case .matchPlay:  return "Win holes head-to-head."
            case .skins:      return "Win a hole outright to earn a skin."
            }
        }

        var roundGameType: RoundGameType {
            RoundGameType(rawValue: rawValue) ?? .strokePlay
        }
    }

    // MARK: - Team (UI + persistence via PlayerTeam)

    private func teamFill(_ team: PlayerTeam?) -> Color {
        guard let team else { return NotesTheme.cardStroke } // neutral
        switch team {
        case .a: return Color.accentColor
        case .b: return Color.secondary.opacity(0.30)
        }
    }

    @Query(sort: \Player.name) private var libraryPlayers: [Player]

    @AppStorage("gsp_last_game_type") private var storedGameRaw: String = ""
    @AppStorage("gsp_last_use_handicaps") private var storedUseHandicaps: Bool = true
    @AppStorage("gsp_last_team_play") private var storedTeamPlay: Bool = false

    // ✅ do NOT default to any game
    @State private var game: GameType? = nil

    // Always available once a game is chosen
    @State private var useHandicaps: Bool = true
    @State private var teamPlay: Bool = false

    // MARK: - Inputs

    @State private var selectedCourse: Course? = nil
    @State private var holes: Int = 18

    // ✅ start with 4 blank slots
    @State private var players: [PlayerDraft] = Array(
        repeating: PlayerDraft(name: "", handicap: 0, team: .a),
        count: 4
    )

    @State private var showCoursePicker = false

    // Handicap wheel picker sheet
    @State private var showHandicapPicker = false
    @State private var handicapPickerIndex: Int? = nil
    @State private var handicapPickerValue: Int = 0

    // Player picker sheet
    @State private var playerPickerIndex: Int? = nil

    // More games menu
    @State private var showMoreGamesMenu = false

    // Toast
    @State private var showComingSoonToast = false
    @State private var comingSoonText: String = "Coming soon"

    // Navigation to live
    @State private var createdRound: Round? = nil
    @State private var goLive = false

    @FocusState private var focusedPlayerIndex: Int?
    private let maxHandicapIndex: Int = 54

    private var accent: Color { Color.accentColor }

    // MARK: - Derived

    private var canStart: Bool {
        guard selectedCourse != nil else { return false }
        guard game != nil else { return false }

        let cleaned = players
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.count >= 1
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                    NotesScreenTitle("New Round", subtitle: "What are we playing today?")

                    gameSection
                    playersSection
                    courseSection

                    // breathing so content never fights the bottom pill
                    Spacer(minLength: 28)
                        .padding(.bottom, 110)
                }
                .padding(.top, GSPUI.Spacing.pageTop)
            }
            .notesBackground()
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            .onTapGesture { focusedPlayerIndex = nil }
            .safeAreaInset(edge: .top) { topBar }
            .safeAreaInset(edge: .bottom) { bottomStartPill }
            .toolbar { keyboardToolbar }

            // Toast (LiveRound-style)
            VStack {
                Spacer()
                if showComingSoonToast {
                    GeometryReader { geo in
                        let w = min(geo.size.width - GSPUI.Spacing.toastSideInset, GSPUI.Size.toastMaxWidth)
                        GSPToastHUD(text: comingSoonText, accent: accent, width: w)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: GSPUI.Spacing.toastContainerHeight)
                    .transition(.opacity)
                    .padding(.bottom, GSPUI.Spacing.toastBottom)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            useHandicaps = storedUseHandicaps
            teamPlay = storedTeamPlay

            if selectedCourse == nil, let first = courses.first {
                selectedCourse = first
                holes = first.totalHoles
            }

            if players.isEmpty {
                players = Array(repeating: PlayerDraft(name: "", handicap: 0, team: .a), count: 4)
            }

            if teamPlay { autoAssignTeamsIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gspDismissToHomeFromFinishRound)) { _ in
            focusedPlayerIndex = nil
            showHandicapPicker = false
            showCoursePicker = false
            showMoreGamesMenu = false
            showComingSoonToast = false
            dismiss()
        }
        // Course picker
        .sheet(isPresented: $showCoursePicker) {
            CoursePickerSheet(
                selection: $selectedCourse,
                onPick: { c in
                    selectedCourse = c
                    holes = c.totalHoles
                }
            )
        }
        // Handicap picker (wheel)
        .sheet(isPresented: $showHandicapPicker) {
            let pickerName: String = {
                guard let idx = handicapPickerIndex,
                      idx >= 0, idx < players.count else { return "Player" }
                let raw = players[idx].name.trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? "Player" : (raw.components(separatedBy: " ").first ?? raw)
            }()

            ValuePickerSheet(
                title: "\(pickerName) Handicap",
                value: $handicapPickerValue,
                range: 0...maxHandicapIndex
            )
            .onDisappear {
                guard let idx = handicapPickerIndex,
                      idx >= 0, idx < players.count else { return }
                players[idx].handicap = handicapPickerValue
                handicapPickerIndex = nil
            }
        }
        // Player picker sheet
        .sheet(isPresented: Binding(
            get: { playerPickerIndex != nil },
            set: { if !$0 { playerPickerIndex = nil } }
        )) {
            if let idx = playerPickerIndex {
                PlayerPickerSheet(
                    library: libraryPlayers,
                    excludingIndex: idx,
                    otherDrafts: players.indices.filter { $0 != idx }.map { players[$0] }
                ) { selected in
                    players[idx].name = selected.name
                    players[idx].handicap = selected.handicap
                    players[idx].selectedLibraryPlayerID = selected.id
                    playerPickerIndex = nil
                }
            }
        }
        // Navigate into LiveRound
        .navigationDestination(isPresented: $goLive) {
            if let createdRound { LiveRoundView(round: createdRound) }
            else { EmptyView() }
        }
        // More Games dropdown
        .confirmationDialog("More Games", isPresented: $showMoreGamesMenu, titleVisibility: .visible) {
            Button("Birdies or Better (BOB)") { comingSoon("Birdies or Better (BOB)") }
            Button("Wolf") { comingSoon("Wolf") }
            Button("Nassau") { comingSoon("Nassau") }
            Button("Vegas") { comingSoon("Vegas") }
            Button("Rabbit") { comingSoon("Rabbit") }
            Button("Snake") { comingSoon("Snake") }
            Button("Bingo Bango Bongo") { comingSoon("Bingo Bango Bongo") }
            Button("Done", role: .cancel) { }
        }
    }

    // MARK: - Top bar (LiveRound canonical)

    private var topBar: some View {
        HStack {
            GSPIconPillButton(systemName: "chevron.left") {
                HapticsManager.light()
                focusedPlayerIndex = nil
                dismiss()
            }

            Spacer()

            // Future use; keep disabled feel.
            GSPIconPillButton(systemName: "ellipsis", isEnabled: false) {
                HapticsManager.light()
            }
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, GSPUI.Spacing.insetTopBarTop)
        .padding(.bottom, GSPUI.Spacing.insetTopBarBottom)
        .background(NotesTheme.bg)
    }

    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                HapticsManager.light()
                focusedPlayerIndex = nil
            }
            .font(.system(size: 16, weight: .semibold, design: .default))
            .foregroundStyle(accent)
        }
    }

    // MARK: - Bottom start pill (canonical)

    private var bottomStartPill: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25)

            Button {
                focusedPlayerIndex = nil
                startRound()
            } label: {
                GSPPrimaryPill(title: "Start Round", accent: accent)
                    .opacity(canStart ? 1.0 : 0.45)
                    .padding(.horizontal, GSPUI.Spacing.insetX)
                    .padding(.top, GSPUI.Spacing.stripVPad)
                    .padding(.bottom, GSPUI.Spacing.holeRowVPad)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canStart)
        }
        .background(NotesTheme.bg)
    }

    // MARK: - Sections

    private var gameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Game")

            VStack(spacing: 10) {
                ForEach(GameType.allCases) { g in
                    Button {
                        HapticsManager.light()
                        focusedPlayerIndex = nil
                        game = g
                        storedGameRaw = g.rawValue
                        if g == .matchPlay {
                            teamPlay = true
                            autoAssignTeamsIfNeeded()
                        } else {
                            teamPlay = storedTeamPlay
                            if teamPlay { autoAssignTeamsIfNeeded() }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.title)
                                .gspFont(.rowTitle)
                                .foregroundStyle(NotesTheme.textPrimary)
                            Text(g.subtitle)
                                .gspFont(.rowSubtitle)
                                .foregroundStyle(NotesTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(game == g ? NotesTheme.accentSoft : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    game == g ? NotesTheme.accent : NotesTheme.cardStroke,
                                    lineWidth: game == g ? 2 : 1
                                )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    HapticsManager.light()
                    focusedPlayerIndex = nil
                    showMoreGamesMenu = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("More Games")
                                .gspFont(.rowTitle)
                                .foregroundStyle(NotesTheme.textPrimary)
                            Text("Future game formats")
                                .gspFont(.rowSubtitle)
                                .foregroundStyle(NotesTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)

            // Toggles retain their “card” feel but spacing matches the system now.
            toggleCard(
                title: "Use Handicaps?",
                subtitle: "Applies stroke index allocation for net results.",
                isOn: Binding(
                    get: { useHandicaps },
                    set: { newValue in
                        useHandicaps = newValue
                        storedUseHandicaps = newValue
                    }
                )
            )
            .disabled(game == nil)
            .opacity(game == nil ? 0.45 : 1.0)

            toggleCard(
                title: "Team Play?",
                subtitle: game == .matchPlay ? "Required for Match Play." : "Assign players to Team A or Team B.",
                isOn: Binding(
                    get: { teamPlay },
                    set: { newValue in
                        teamPlay = newValue
                        storedTeamPlay = newValue
                        if teamPlay { autoAssignTeamsIfNeeded() }
                    }
                )
            )
            .disabled(game == nil || game == .matchPlay)
            .opacity((game == nil || game == .matchPlay) ? 0.45 : 1.0)
        }
        .padding(.top, 2)
    }

    private func toggleCard(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.title3, design: .default).weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(NotesTheme.textSecondary)
                    .font(.system(.body, design: .default))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: accent))
        .padding(GSPUI.Spacing.cardPad)
        .background(NotesTheme.cardStrong)
        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
        .padding(.horizontal, GSPUI.Spacing.insetX)
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                sectionHeader("Players")
                Spacer()

                Button {
                    HapticsManager.light()
                    focusedPlayerIndex = nil
                    addPlayer()
                    if teamPlay { autoAssignTeamsIfNeeded() }
                } label: {
                    Text("Add")
                        .font(.system(.headline, design: .default))
                        .foregroundStyle(NotesTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(players.count >= 8)
                .opacity(players.count >= 8 ? 0.45 : 1.0)
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)

            GSPListBlock {
                VStack(spacing: 0) {
                    ForEach(players.indices, id: \.self) { idx in
                        playerRow(idx)

                        if idx != players.indices.last {
                            GSPDivider(leading: GSPUI.Spacing.dividerLeading)
                        }
                    }
                }
            }
        }
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Course")

            GSPListBlock {
                VStack(spacing: 0) {
                    FlatChevronRow(
                        title: selectedCourse?.name ?? "Select a course",
                        subtitle: selectedCourseSubtitle,
                        trailing: selectedCourse == nil ? nil : "\(holes)"
                    ) {
                        HapticsManager.light()
                        focusedPlayerIndex = nil
                        showCoursePicker = true
                    }
                }
            }

            HStack(spacing: 10) {
                holesChip(9)
                holesChip(18)
                Spacer()
            }
            .padding(.horizontal, GSPUI.Spacing.insetX)
            .padding(.top, 8)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(NotesTheme.textPrimary)
            .font(.system(.title3, design: .default).weight(.semibold))
            .padding(.horizontal, GSPUI.Spacing.insetX)
    }

    // MARK: - Player row

    private func playerRow(_ idx: Int) -> some View {
        let binding = Binding<PlayerDraft>(
            get: { players[idx] },
            set: { players[idx] = $0 }
        )

        let fill = teamPlay ? teamFill(binding.wrappedValue.team) : NotesTheme.cardStroke

        return VStack(alignment: .leading, spacing: 0) {

            // ── Line 1: avatar · name · HCP · remove ────────────────────────
            HStack(spacing: GSPUI.Spacing.rowHStack) {
                // Avatar button: magnifying glass when empty, initials once filled.
                // Tapping opens the library picker sheet.
                let hasName = !binding.wrappedValue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    HapticsManager.light()
                    focusedPlayerIndex = nil
                    playerPickerIndex = idx
                } label: {
                    if hasName {
                        GSPAvatarCircle(
                            initials: initials(for: binding.wrappedValue.name),
                            size: GSPUI.Size.avatar,
                            fill: fill
                        )
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: GSPUI.Size.avatar * 0.38, weight: .semibold))
                            .foregroundStyle(NotesTheme.textSecondary)
                            .frame(width: GSPUI.Size.avatar, height: GSPUI.Size.avatar)
                            .background(
                                Circle()
                                    .fill(NotesTheme.card)
                                    .overlay(Circle().stroke(NotesTheme.cardStroke, lineWidth: 1))
                            )
                    }
                }
                .buttonStyle(.plain)

                TextField("Player name", text: binding.name)
                    .focused($focusedPlayerIndex, equals: idx)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { focusedPlayerIndex = nil }
                    .font(.system(.title3, design: .default).weight(.semibold))
                    .foregroundStyle(NotesTheme.textPrimary)

                Spacer(minLength: 0)

                Button {
                    HapticsManager.light()
                    focusedPlayerIndex = nil
                    handicapPickerIndex = idx
                    handicapPickerValue = players[idx].handicap
                    showHandicapPicker = true
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("HCP")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundStyle(NotesTheme.textTertiary)

                            Text("\(players[idx].handicap)")
                                .font(.system(.title3, design: .default).weight(.semibold))
                                .foregroundStyle(NotesTheme.textPrimary)
                                .monospacedDigit()
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                if players.count > 1 {
                    Button {
                        HapticsManager.light()
                        focusedPlayerIndex = nil
                        removePlayer(idx)
                        if teamPlay { autoAssignTeamsIfNeeded() }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove player")
                }
            }
            .padding(.top, GSPUI.Spacing.rowVPad)
            .padding(.bottom, teamPlay ? 10 : GSPUI.Spacing.rowVPad)

            // ── Line 2: team assignment chips (team play only) ───────────────
            if teamPlay {
                HStack(spacing: 10) {
                    // Indent to align with name field (avatar width + rowHStack gap)
                    Spacer()
                        .frame(width: GSPUI.Size.avatar + GSPUI.Spacing.rowHStack)

                    ForEach(PlayerTeam.allCases) { team in
                        let isSelected = (binding.wrappedValue.team ?? .a) == team
                        Button {
                            HapticsManager.light()
                            binding.wrappedValue.team = team
                        } label: {
                            Text(team.rawValue == "A" ? "TEAM A" : "TEAM B")
                                .font(.system(size: 13, weight: .bold, design: .default))
                                .foregroundStyle(isSelected ? NotesTheme.textPrimary : NotesTheme.textTertiary)
                                .tracking(0.5)
                                .frame(minWidth: 80, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? teamFill(team) : NotesTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? Color.clear : NotesTheme.divider,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(team.label), \(isSelected ? "selected" : "not selected")")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, teamPlay ? 4 : GSPUI.Spacing.rowVPad)
            }

        }
        .contentShape(Rectangle())
        // Clear the library link if the user manually edits the name after selecting from library
        .onChange(of: binding.wrappedValue.name) { newName in
            if binding.wrappedValue.selectedLibraryPlayerID != nil {
                let linked = libraryPlayers.first(where: { $0.id == binding.wrappedValue.selectedLibraryPlayerID })
                if let linked, normalizeName(newName) != normalizeName(linked.name) {
                    binding.wrappedValue.selectedLibraryPlayerID = nil
                }
            }
        }
    }

    // MARK: - Course helpers

    private var selectedCourseSubtitle: String {
        guard let c = selectedCourse else {
            return "Choose an existing course or create a new one."
        }
        let par = c.pars.prefix(c.totalHoles).reduce(0, +)
        return "\(c.totalHoles) holes • Par \(par)"
    }

    private func holesChip(_ n: Int) -> some View {
        Button {
            HapticsManager.light()
            focusedPlayerIndex = nil
            holes = n
        } label: {
            Text("\(n) holes")
                .font(.system(.headline, design: .default))
                .foregroundStyle(holes == n ? NotesTheme.textPrimary : NotesTheme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(holes == n ? NotesTheme.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            holes == n ? NotesTheme.accent : NotesTheme.cardStroke,
                            lineWidth: holes == n ? 2 : 1
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
        .buttonStyle(.plain)
        .disabled(selectedCourse == nil)
        .opacity(selectedCourse == nil ? 0.45 : 1.0)
    }

    // MARK: - Start round

    private func startRound() {
        guard let course = selectedCourse else { return }
        guard let game else { return }

        let cleanDrafts = players
            .map {
                PlayerDraft(
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    handicap: $0.handicap,
                    team: $0.team
                )
            }
            .filter { !$0.name.isEmpty }

        guard !cleanDrafts.isEmpty else { return }

        // Resolve each draft against the library: reuse an existing player (updating handicap/team),
        // or create and insert a new library player if no normalized-name match is found.
        let allLibraryPlayers = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        let playerModels: [Player] = cleanDrafts.map { d in
            resolveOrCreatePlayer(draft: d, library: allLibraryPlayers)
        }

        let snapPars = Array(course.pars.prefix(holes))
        let snapSI = Array(course.strokeIndex.prefix(holes))

        let round = Round(
            courseName: course.name,
            totalHoles: holes,
            status: .inProgress,
            currentHole: 1,
            players: playerModels,
            scores: [],
            pars: snapPars,
            strokeIndex: snapSI,
            course: course,
            gameType: game.roundGameType,
            useHandicaps: useHandicaps,
            teamPlay: teamPlay
        )

        context.insert(round)

        do {
            try context.save()
            HapticsManager.success()
            createdRound = round
            goLive = true
        } catch {
            print("Start round save failed: \(error)")
        }
    }

    // MARK: - Player resolution

    /// Finds an existing library player and updates their handicap/team, or creates a new one.
    /// Prefers ID-based match (when user tapped a suggestion) over normalized-name fallback.
    private func resolveOrCreatePlayer(draft: PlayerDraft, library: [Player]) -> Player {
        let assignedTeam = teamPlay ? (draft.team ?? .a) : .a

        // Fast path: user selected from suggestions — match by ID
        if let selectedID = draft.selectedLibraryPlayerID,
           let existing = library.first(where: { $0.id == selectedID }) {
            existing.handicap = draft.handicap
            existing.team = assignedTeam
            return existing
        }

        // Fallback: normalize-name match
        let key = normalizeName(draft.name)
        if let existing = library.first(where: { normalizeName($0.name) == key }) {
            existing.handicap = draft.handicap
            existing.team = assignedTeam
            return existing
        }

        // New player
        let new = Player(name: draft.name, handicap: draft.handicap, team: assignedTeam)
        context.insert(new)
        return new
    }

    private func normalizeName(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    // MARK: - Player list helpers

    private func addPlayer() {
        guard players.count < 8 else { return }
        players.append(PlayerDraft(name: "", handicap: 0, team: .a))
    }

    private func removePlayer(_ idx: Int) {
        guard idx >= 0 && idx < players.count else { return }
        players.remove(at: idx)
        if players.isEmpty {
            players = Array(repeating: PlayerDraft(name: "", handicap: 0, team: .a), count: 4)
        }
    }

    private func autoAssignTeamsIfNeeded() {
        for i in players.indices {
            players[i].team = (i % 2 == 0) ? .a : .b
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
        let last = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - More games feedback

    private func comingSoon(_ title: String) {
        comingSoonText = "\(title) • Coming soon"
        HapticsManager.light()

        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            showComingSoonToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                showComingSoonToast = false
            }
        }
    }
}

// MARK: - Draft model (UI only)

private struct PlayerDraft: Equatable {
    var name: String
    var handicap: Int
    var team: PlayerTeam?
    /// Set when the user taps a library suggestion. Cleared if the name is edited afterward.
    var selectedLibraryPlayerID: UUID? = nil
}

// MARK: - Flat row helpers (kept local; now used inside GSPListBlock)

private struct FlatChevronRow: View {
    let title: String
    let subtitle: String?
    var trailing: String? = nil
    var trailingSystemImage: String? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(NotesTheme.textPrimary)
                        .font(.system(.title3, design: .default).weight(.semibold))
                        .lineLimit(2)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .foregroundStyle(NotesTheme.textSecondary)
                            .font(.system(.body, design: .default))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .foregroundStyle(NotesTheme.textTertiary)
                        .font(.system(.body, design: .default).weight(.semibold))
                }

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(NotesTheme.textTertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(NotesTheme.textTertiary)
                }
            }
            .padding(.vertical, GSPUI.Spacing.rowVPad)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Course Picker (unchanged from your version, just swapped top bar button)

private struct CoursePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @Binding var selection: Course?
    var onPick: (Course) -> Void

    @State private var showEditor = false
    @State private var editing: Course? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                NotesScreenTitle("Courses", subtitle: "Pick one to start scoring.")

                Button {
                    HapticsManager.light()
                    editing = nil
                    showEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundStyle(.black)
                        Text("New Course")
                            .font(.system(.title3, design: .default).weight(.semibold))
                            .foregroundStyle(.black)
                        Spacer()
                    }
                    .padding(.horizontal, GSPUI.Spacing.cardPad)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, GSPUI.Spacing.insetX)

                if courses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No courses yet")
                            .font(.system(.title2, design: .default).weight(.semibold))
                            .foregroundStyle(NotesTheme.textPrimary)

                        Text("Create your first course to begin.")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(NotesTheme.textSecondary)
                    }
                    .padding(GSPUI.Spacing.cardPad)
                    .notesCard()
                    .padding(.horizontal, GSPUI.Spacing.insetX)
                } else {
                    GSPListBlock {
                        VStack(spacing: 0) {
                            ForEach(courses, id: \.id) { c in
                                FlatChevronRow(
                                    title: c.name,
                                    subtitle: "\(c.totalHoles) holes • Par \(c.pars.prefix(c.totalHoles).reduce(0,+))",
                                    trailing: (selection?.id == c.id) ? "✓" : nil
                                ) {
                                    selection = c
                                    onPick(c)
                                    HapticsManager.success()
                                    dismiss()
                                }

                                if c.id != courses.last?.id {
                                    GSPDivider(leading: GSPUI.Spacing.insetX)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .notesBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) { topBar }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                CourseEditorSheet(existing: editing) { _ in }
            }
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
}
// MARK: - Player Picker Sheet

private struct PlayerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Round.createdAt, order: .reverse) private var allRounds: [Round]

    let library: [Player]
    let excludingIndex: Int
    let otherDrafts: [PlayerDraft]
    let onSelect: (Player) -> Void

    @State private var searchText = ""

    /// IDs and names of players already assigned to other rows.
    private var excludedIDs: Set<UUID> {
        Set(otherDrafts.compactMap { $0.selectedLibraryPlayerID })
    }
    private var excludedNames: Set<String> {
        Set(otherDrafts.map { normalizeName($0.name) }.filter { !$0.isEmpty })
    }

    /// Up to 3 distinct library players drawn from the most-recent completed rounds.
    private var recentPlayers: [Player] {
        var seen = Set<UUID>()
        var result: [Player] = []
        for round in allRounds where round.status == .completed {
            for rp in round.players {
                guard result.count < 3 else { return result }
                guard !seen.contains(rp.id) else { continue }
                guard !excludedIDs.contains(rp.id) else { continue }
                guard !excludedNames.contains(normalizeName(rp.name)) else { continue }
                if let lib = library.first(where: { $0.id == rp.id }) {
                    seen.insert(lib.id)
                    result.append(lib)
                }
            }
        }
        return result
    }

    /// All library players not in recent list and not excluded, alphabetized, filtered by search.
    private var allPlayers: [Player] {
        let recentIDs = Set(recentPlayers.map { $0.id })
        let q = normalizeName(searchText)
        return library
            .filter { p in
                guard !recentIDs.contains(p.id) else { return false }
                guard !excludedIDs.contains(p.id) else { return false }
                guard !excludedNames.contains(normalizeName(p.name)) else { return false }
                if !q.isEmpty { return normalizeName(p.name).contains(q) }
                return true
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Recent players filtered by search text.
    private var filteredRecent: [Player] {
        let q = normalizeName(searchText)
        guard !q.isEmpty else { return recentPlayers }
        return recentPlayers.filter { normalizeName($0.name).contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredRecent.isEmpty {
                    Section("Recent") {
                        ForEach(filteredRecent) { player in
                            playerRow(player)
                        }
                    }
                }

                Section(filteredRecent.isEmpty ? "Players" : "All Players") {
                    if allPlayers.isEmpty && filteredRecent.isEmpty {
                        Text("No players found")
                            .foregroundStyle(NotesTheme.textSecondary)
                            .font(.system(.body))
                    } else {
                        ForEach(allPlayers) { player in
                            playerRow(player)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search players")
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.light()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playerRow(_ player: Player) -> some View {
        Button {
            HapticsManager.light()
            onSelect(player)
        } label: {
            HStack(spacing: 12) {
                Text(player.name)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .font(.system(.body, design: .default))
                Spacer(minLength: 0)
                if player.handicap > 0 {
                    Text("HCP \(player.handicap)")
                        .foregroundStyle(NotesTheme.textSecondary)
                        .font(.system(.subheadline, design: .default).monospacedDigit())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func normalizeName(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

