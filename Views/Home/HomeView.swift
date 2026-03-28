//
//  HomeView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-27  (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - Home owns the NavigationStack path so we can reliably “pop to Home”
//  - When a round is finished and `.gspDismissToHomeFromFinishRound` posts,
//    Home immediately returns to root (Home) and closes any presented setup sheet
//  - Library card compiles (no dependency on a missing `GSPUI.Radius.card`)
//  - Keeps your premium “roll up” RoundSetup sheet presentation
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Round.createdAt, order: .reverse) private var rounds: [Round]

    @State private var showRoundSetup = false

    // ✅ Own navigation so we can pop-to-root from notifications
    @State private var path = NavigationPath()

    private var activeRound: Round? {
        rounds.first(where: { $0.status == .inProgress })
    }

    private var accent: Color { .accentColor }

    // MARK: - Routes (Hashable for NavigationPath)
    private enum Route: Hashable {
        case live(UUID)
        case rounds
        case courses
        case players
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                    homeHeroHeader

                    // HERO ACTIONS
                    VStack(spacing: 12) {
                        if let r = activeRound {
                            NavigationLink(value: Route.live(r.id)) {
                                heroActionPill(
                                    title: "Resume Round",
                                    subtitle: "Hole \(r.currentHole) • \(r.courseName)"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                HapticsManager.light()
                                showRoundSetup = true
                            } label: {
                                heroActionPill(
                                    title: "Start New Round",
                                    subtitle: rounds.isEmpty ? "No rounds yet • Start to begin" : "Create a new scorecard"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, GSPUI.Spacing.insetX)

                    // LIBRARY
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Library")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundStyle(NotesTheme.textTertiary)
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.top, 6)

                        VStack(spacing: 0) {

                            NavigationLink(value: Route.rounds) {
                                NotesChevronRowLabel(
                                    title: "Rounds",
                                    subtitle: "View • Delete",
                                    trailing: ""
                                )
                                .padding(.vertical, GSPUI.Spacing.rowVPad)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(Color.white.opacity(GSPUI.Opacity.divider))
                                .padding(.leading, GSPUI.Spacing.insetX)

                            NavigationLink(value: Route.courses) {
                                NotesChevronRowLabel(
                                    title: "Courses",
                                    subtitle: "Select • Add • Edit",
                                    trailing: ""
                                )
                                .padding(.vertical, GSPUI.Spacing.rowVPad)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(Color.white.opacity(GSPUI.Opacity.divider))
                                .padding(.leading, GSPUI.Spacing.insetX)

                            NavigationLink(value: Route.players) {
                                NotesChevronRowLabel(
                                    title: "Players",
                                    subtitle: "Optional • For faster setup",
                                    trailing: ""
                                )
                                .padding(.vertical, GSPUI.Spacing.rowVPad)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                        .background(NotesTheme.cardStrong)
                        .clipShape(RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: NotesTheme.rowRadius, style: .continuous)
                                .strokeBorder(NotesTheme.divider, lineWidth: 1)
                        )
                        .padding(.horizontal, GSPUI.Spacing.insetX)
                    }

                    Spacer(minLength: 28)
                }
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .notesBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRoundSetup) {
                NavigationStack { RoundSetupView() }
            }
            // ✅ Pop-to-home from anywhere when a round is finished
            .onReceive(NotificationCenter.default.publisher(for: .gspDismissToHomeFromFinishRound)) { _ in
                // Close any presented “global” UI first
                showRoundSetup = false

                // Pop navigation back to Home
                path = NavigationPath()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .live(let id):
                    if let r = rounds.first(where: { $0.id == id }) {
                        LiveRoundView(round: r)
                    } else {
                        EmptyView()
                    }

                case .rounds:
                    RoundsView()

                case .courses:
                    CoursesView()

                case .players:
                    PlayersView()
                }
            }
        }
    }

    // MARK: - Hero Header

    private var homeHeroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GolfScorePro")
                .font(.system(size: 44, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)

            Text("Score fast. Stay focused.")
                .font(.system(size: 20, weight: .regular, design: .default))
                .foregroundStyle(NotesTheme.textSecondary)
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .padding(.top, 6)
    }

    // MARK: - Hero pill (no icons; clean + fast)

    private func heroActionPill(title: String, subtitle: String) -> some View {
        HStack(spacing: GSPUI.Spacing.rowHStack) {

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundStyle(.black.opacity(0.92))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .foregroundStyle(.black.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundStyle(.black.opacity(GSPUI.Opacity.chevron))
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(accent)
        )
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func secondaryActionPill(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textTertiary)
        }
        .padding(.horizontal, GSPUI.Spacing.insetX)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(NotesTheme.divider, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
