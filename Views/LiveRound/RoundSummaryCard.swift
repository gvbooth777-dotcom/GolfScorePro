import SwiftUI

// MARK: - RoundSummaryData
//
// Plain value-type snapshot of everything the card needs.
// Extracted from the SwiftData model on the main actor BEFORE
// passing to ImageRenderer (which has no ModelContext).

struct RoundSummaryData {
    let courseName:   String
    let gameType:     RoundGameType
    let useHandicaps: Bool
    let thruHole:     Int
    let coursePar:    Int
    let rows:         [LeaderboardRow]  // sorted: winner first

    /// Build from a live Round model. Must be called where the model context is active.
    init(round: Round) {
        let input = RoundInput(from: round)
        let thru  = StrokePlayEngine.computeThruHole(input)
        let effectiveThru = thru > 0 ? thru : input.course.holeCount
        let built = StrokePlayEngine.buildRows(for: input, through: effectiveThru)
        let sorted = built.sorted {
            if $0.grossDelta != $1.grossDelta { return $0.grossDelta < $1.grossDelta }
            if $0.grossTotal != $1.grossTotal { return $0.grossTotal < $1.grossTotal }
            return $0.name < $1.name
        }

        self.courseName   = round.courseName
        self.gameType     = round.gameType
        self.useHandicaps = round.useHandicaps
        self.thruHole     = effectiveThru
        self.coursePar    = input.course.totalPar
        self.rows         = sorted
    }
}

// MARK: - RoundSummaryCard
//
// NOTE: This card renders via ImageRenderer to a UIImage for sharing.
// .ultraThinMaterial is NOT renderable by ImageRenderer — keep solid fills.

struct RoundSummaryCard: View {

    let data: RoundSummaryData

    // MARK: - Adaptive colors (solid fills only — ImageRenderer requirement)

    private static let cardBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.07, alpha: 1)
            : UIColor(white: 0.97, alpha: 1)
    })
    private static let primaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0.102, green: 0.180, blue: 0.102, alpha: 1)
    })
    private static let text80 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.80)
            : UIColor(white: 0, alpha: 0.70)
    })
    private static let text55 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.55)
            : UIColor(white: 0, alpha: 0.45)
    })
    private static let text35 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.35)
            : UIColor(white: 0, alpha: 0.28)
    })
    private static let text30 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.30)
            : UIColor(white: 0, alpha: 0.25)
    })
    private static let text25 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.25)
            : UIColor(white: 0, alpha: 0.18)
    })
    private static let evenDelta = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.45)
            : UIColor(white: 0, alpha: 0.35)
    })
    private static let text75 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.75)
            : UIColor(white: 0, alpha: 0.60)
    })

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBlock
            Divider().overlay(NotesTheme.divider)
            standingsBlock
            footerBlock
        }
        .frame(width: 360)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(NotesTheme.cardStroke, lineWidth: 1)
        )
    }

    // MARK: - Header: course / game / mode

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.courseName)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(Self.primaryText)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(data.gameType.displayName)
                    .font(.system(.subheadline, design: .default))
                    .foregroundStyle(Self.text55)

                if data.gameType == .strokePlay {
                    Text("·")
                        .foregroundStyle(Self.text30)
                    Text(data.useHandicaps ? "Net" : "Gross")
                        .font(.system(.subheadline, design: .default))
                        .foregroundStyle(Self.text55)
                }

                Text("·")
                    .foregroundStyle(Self.text30)
                Text("Thru \(data.thruHole)")
                    .font(.system(.subheadline, design: .default))
                    .foregroundStyle(Self.text55)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(NotesTheme.accentSoft)
        )
    }

    // MARK: - Standings block

    private var standingsBlock: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.rows.enumerated()), id: \.element.id) { idx, row in
                playerRow(row, position: idx + 1)

                if idx < data.rows.count - 1 {
                    Divider()
                        .overlay(NotesTheme.divider)
                        .padding(.leading, 20)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func playerRow(_ row: LeaderboardRow, position: Int) -> some View {
        let isWinner = (position == 1)
        let delta    = data.useHandicaps ? row.netDelta  : row.grossDelta
        let total    = data.useHandicaps ? row.netTotal  : row.grossTotal
        let dText    = deltaText(delta)
        let dColor   = deltaColor(delta)

        return HStack(spacing: 12) {
            Text("\(position)")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Self.text35)
                .frame(width: 20, alignment: .center)
                .monospacedDigit()

            Text(row.name)
                .font(isWinner
                    ? .system(.title3, design: .default).weight(.bold)
                    : .system(.body, design: .default).weight(.medium))
                .foregroundStyle(isWinner ? Self.primaryText : Self.text80)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(dText)
                .font(isWinner
                    ? .system(.title3, design: .default).weight(.bold)
                    : .system(.body, design: .default).weight(.semibold))
                .foregroundStyle(dColor)
                .monospacedDigit()

            Text("\(total)")
                .font(isWinner
                    ? .system(size: 28, weight: .bold, design: .default)
                    : .system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(isWinner ? Self.primaryText : Self.text75)
                .monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, isWinner ? 16 : 12)
    }

    // MARK: - Footer

    private var footerBlock: some View {
        HStack {
            Text("Par \(data.coursePar)")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Self.text30)

            Spacer()

            Text("GolfScorePro")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Self.text25)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Formatting helpers

    private func deltaText(_ d: Int) -> String {
        if d == 0 { return "E" }
        return d < 0 ? "\(d)" : "+\(d)"
    }

    private func deltaColor(_ d: Int) -> Color {
        if d < 0 { return Color.accentColor }
        if d > 0 { return Color.red }
        return Self.evenDelta
    }
}

// MARK: - Share entry point

extension RoundSummaryCard {

    /// Call this on the main actor (where the model context is live).
    /// Extracts all data from `round` immediately, then renders + presents share sheet.
    @MainActor
    static func share(round: Round) {
        // Step 1: snapshot all model data while we have a live context
        let data = RoundSummaryData(round: round)

        // Step 2: render the frozen card (no model object inside the renderer)
        let card = RoundSummaryCard(data: data)
        let renderer = ImageRenderer(content: card.padding(24))
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(width: 408, height: nil)

        guard let image = renderer.uiImage else {
            // Fallback: share text only
            presentShareSheet(items: [shareText(from: data)])
            return
        }

        presentShareSheet(items: [image, shareText(from: data)])
    }

    @MainActor
    private static func presentShareSheet(items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .addToReadingList]

        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        // Walk to the topmost presented controller so share sheet
        // presents over any sheets already on screen (e.g. roundCompleteSheet)
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        // iPad popover anchor
        if let popover = vc.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(
                x: top.view.bounds.midX,
                y: top.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        top.present(vc, animated: true)
    }

    private static func shareText(from data: RoundSummaryData) -> String {
        let modeLabel = data.useHandicaps ? "Net" : "Gross"
        let header = "\(data.courseName) · \(data.gameType.displayName) · \(modeLabel) · Thru \(data.thruHole)"
        let lines = data.rows.enumerated().map { idx, row -> String in
            let delta = data.useHandicaps ? row.netDelta  : row.grossDelta
            let total = data.useHandicaps ? row.netTotal  : row.grossTotal
            let dText = delta == 0 ? "E" : (delta < 0 ? "\(delta)" : "+\(delta)")
            return "\(idx + 1). \(row.name)  \(dText)  (\(total))"
        }
        return ([header, ""] + lines + ["", "Scored with GolfScorePro"]).joined(separator: "\n")
    }
}
