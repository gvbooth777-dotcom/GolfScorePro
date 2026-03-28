import SwiftUI

/// Label-only version of NotesChevronRow.
/// Use inside NavigationLink labels where you don't want an action closure.
struct NotesChevronRowLabel: View {
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(NotesTheme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(NotesTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 14, weight: .semibold, design: .default))
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
