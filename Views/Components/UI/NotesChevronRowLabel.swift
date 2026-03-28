import SwiftUI

/// Label-only version of NotesChevronRow.
/// Use inside NavigationLink labels where you don't want an action closure.
struct NotesChevronRowLabel: View {
    let title: String
    let subtitle: String
    let trailing: String
    var icon: String? = nil   // SF Symbol name; shows accentSoft circle when set

    var body: some View {
        HStack(spacing: 14) {

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotesTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(NotesTheme.accentSoft))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .gspFont(.rowTitle)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .gspFont(.rowSubtitle)
                        .foregroundStyle(NotesTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if !trailing.isEmpty {
                Text(trailing)
                    .gspFont(.rowTrailing)
                    .foregroundStyle(NotesTheme.textTertiary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(NotesTheme.textTertiary)
        }
        .padding(16)
        .notesRowSurface()
        .accessibilityElement(children: .combine)
    }
}
