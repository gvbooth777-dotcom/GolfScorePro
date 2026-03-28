//
//  ValuePickerSheet.swift
//  GolfScorePro
//
//  Refactor: 2026-02-16 14:xx PT
//
//  What you should see now:
//  - Sheet title + Done use the shared typography layer (Apple-native fonts).
//  - Fixes “Cannot infer contextual base in reference to member 'sheetTitle'”.
//

import SwiftUI

struct ValuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(title)
                    .foregroundStyle(NotesTheme.textPrimary)
                    .gspFont(.sheetTitle)

                Spacer()

                Button("Done") {
                    HapticsManager.success()
                    dismiss()
                }
                .foregroundStyle(NotesTheme.accent)
                .gspFont(.sheetAction)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Picker("", selection: $value) {
                ForEach(range, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: 30, weight: .semibold, design: .default))
                        .foregroundStyle(NotesTheme.textPrimary)
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .onChange(of: value) { _ in HapticsManager.light() }
            .padding(.horizontal, 6)

            Spacer(minLength: 0)
        }
        .notesBackground()
        .presentationDetents([.medium])
    }
}
