//
//  CoursesView.swift
//  GolfScorePro
//
//  Refactor: 2026-02-25 (LiveRoundView UI Source of Truth)
//
//  WHAT YOU SHOULD SEE NOW
//  - Same breathing + row rhythm as LiveRoundView
//  - Same top-bar icon pills as LiveRoundView
//  - NO swipe-to-delete (glove-friendly)
//  - Tap a course row → opens CourseEditorSheet
//  - Explicit trailing "…" menu per row → Delete Course (two-step)
//  - Bottom "New Course" CTA pill stays canonical + thumb-friendly
//

import SwiftUI
import SwiftData

struct CoursesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var showingNewCourse: Bool = false
    @State private var editingCourse: Course? = nil

    @State private var menuCourse: Course? = nil
    @State private var showRowMenu: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var accent: Color { .accentColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSPUI.Spacing.sectionVStack) {

                    NotesScreenTitle("Courses", subtitle: "Tap to edit • Add • Delete")

                    if courses.isEmpty {
                        emptyState
                            .padding(.horizontal, GSPUI.Spacing.insetX)
                            .padding(.top, 2)
                    } else {
                        GSPListBlock {
                            VStack(spacing: 0) {
                                ForEach(courses) { c in
                                    CourseRow(
                                        course: c,
                                        onOpen: {
                                            HapticsManager.light()
                                            editingCourse = c
                                        },
                                        onMenu: {
                                            HapticsManager.light()
                                            menuCourse = c
                                            showRowMenu = true
                                        }
                                    )

                                    if c.id != courses.last?.id {
                                        GSPDivider(leading: GSPUI.Spacing.dividerLeading)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 28)
                        .padding(.bottom, 110) // breathing so last row doesn't fight the pill
                }
                .padding(.top, GSPUI.Spacing.pageTop)
            }
            .notesBackground()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { topBar }

            bottomPill
        }
        .sheet(isPresented: $showingNewCourse) {
            CourseEditorSheet(existing: nil) { _ in }
        }
        .sheet(item: $editingCourse) { course in
            CourseEditorSheet(existing: course) { _ in }
        }

        // Step 1: row menu
        .confirmationDialog(
            "Course",
            isPresented: $showRowMenu,
            titleVisibility: .visible
        ) {
            Button("Delete Course…", role: .destructive) {
                HapticsManager.medium()
                showDeleteConfirm = true
            }

            Button("Done", role: .cancel) {
                menuCourse = nil
            }
        } message: {
            if let c = menuCourse {
                Text("\(c.name)\n\(c.totalHoles) holes")
            }
        }

        // Step 2: confirm delete (keep this visually consistent with your other menus)
        .confirmationDialog(
            "Delete this course?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Course", role: .destructive) {
                if let c = menuCourse {
                    deleteCourse(c)
                }
                menuCourse = nil
            }

            Button("Keep Course", role: .cancel) { }
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

            Spacer()

            GSPIconPillButton(systemName: "ellipsis") {
                // future menu (sort/export)
                HapticsManager.light()
            }
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

            Button {
                HapticsManager.light()
                showingNewCourse = true
            } label: {
                GSPPrimaryPill(title: "New Course", accent: accent)
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
            Text("No courses yet")
                .foregroundStyle(NotesTheme.textPrimary)
                .font(.system(.title2, design: .default).weight(.semibold))

            Text("Tap New Course to add your first course.")
                .foregroundStyle(NotesTheme.textSecondary)
                .font(.system(.body, design: .default))
        }
        .padding(GSPUI.Spacing.cardPad)
        .notesCard()
    }

    // MARK: - Delete

    private func deleteCourse(_ course: Course) {
        context.delete(course)
        try? context.save()
        HapticsManager.success()
    }
}

// MARK: - Row (LiveRound rhythm + explicit menu)

private struct CourseRow: View {
    let course: Course
    let onOpen: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {

            Button(action: onOpen) {
                HStack(alignment: .center, spacing: GSPUI.Spacing.rowHStack) {
                    GSPAvatarCircle(
                        initials: initials(from: course.name),
                        size: GSPUI.Size.avatar,
                        fill: Color.white.opacity(0.14)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .foregroundStyle(NotesTheme.textPrimary)
                            .font(.system(.title3, design: .default).weight(.semibold))
                            .lineLimit(1)

                        Text("\(course.totalHoles) holes")
                            .foregroundStyle(NotesTheme.textSecondary)
                            .font(.system(.body, design: .default))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Explicit menu target (separate button, avoids accidental open)
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

    private func initials(from text: String) -> String {
        let parts = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        if parts.isEmpty { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(2)).uppercased() }

        let first = parts.first?.prefix(1) ?? ""
        let last  = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
}
