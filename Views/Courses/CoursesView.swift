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
        VStack(spacing: 16) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(NotesTheme.textTertiary)

            Text("No Courses Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NotesTheme.textPrimary)

            Text("Add a course to track par and stroke index.")
                .font(.subheadline)
                .foregroundStyle(NotesTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotesTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(NotesTheme.accentSoft))

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

}
