import SwiftUI

// Pilot stats from the local run log. Free pilots see their recent form;
// Premium reads the whole history.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premium = Premium.shared
    @State private var showPaywall = false

    private let allRuns = RunHistory.all().reversed().map { $0 }

    private var visibleRuns: [RunRecord] {
        premium.isActive ? allRuns : Array(allRuns.prefix(5))
    }

    private var caption: String { premium.isActive ? "ALL TIME" : "LAST 5 RUNS" }

    var body: some View {
        ZStack {
            GalaxyBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Text("PILOT STATS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 24)
                    Text("PILOT LV \(Progress.level) · \(caption)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.gold)

                    if visibleRuns.isEmpty {
                        Text("Fly a run first — stats land here.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textDim)
                            .padding(.top, 60)
                    } else {
                        statGrid
                        deathBreakdown
                        recentRuns
                    }

                    if !premium.isActive && allRuns.count > 5 {
                        Button { showPaywall = true } label: {
                            Label("Full history with Premium", systemImage: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 26)
                                .background(Theme.gold, in: Capsule())
                        }
                        .padding(.top, 4)
                    }

                    Button("CLOSE") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showPaywall) { PremiumView() }
    }

    private var statGrid: some View {
        let runs = visibleRuns
        let bestScore = runs.map(\.score).max() ?? 0
        let avg = runs.isEmpty ? 0 : runs.map(\.score).reduce(0, +) / runs.count
        let captures = runs.map(\.captures).reduce(0, +)
        let perfects = runs.map(\.perfects).reduce(0, +)
        let rate = captures > 0 ? Int(Double(perfects) / Double(captures) * 100) : 0
        let topSector = runs.map(\.maxSector).max() ?? 1
        let bestStreak = runs.map(\.longestStreak).max() ?? 0
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                         spacing: 12) {
            statTile("BEST", "\(bestScore)")
            statTile("AVG SCORE", "\(avg)")
            statTile("RUNS", "\(runs.count)")
            statTile("PERFECT RATE", "\(rate)%")
            statTile("TOP SECTOR", "\(topSector)")
            statTile("BEST STREAK", bestStreak > 0 ? "×\(min(bestStreak, 5))" : "—")
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var deathBreakdown: some View {
        let runs = visibleRuns
        let causes: [(String, String, Color)] = [
            ("drift", "DRIFTED OFF", Color(uiColor: Palette.cyan)),
            ("wall", "ASTEROID WALLS", Color(uiColor: Palette.unstableRed)),
            ("gate", "GATES", Theme.gold),
        ]
        let total = max(runs.count, 1)
        return VStack(spacing: 10) {
            Text("HOW YOUR RUNS END")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textDim)
            ForEach(causes, id: \.0) { cause, label, color in
                let count = runs.filter { $0.deathCause == cause }.count
                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(color)
                                .frame(width: max(geo.size.width * CGFloat(count) / CGFloat(total), count > 0 ? 8 : 0))
                        }
                    }
                    .frame(height: 8)
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 26, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var recentRuns: some View {
        VStack(spacing: 8) {
            Text("RUN LOG")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textDim)
            ForEach(visibleRuns.prefix(premium.isActive ? 30 : 5)) { run in
                HStack {
                    Text(run.mode.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(run.mode == "daily" ? Theme.gold : Theme.textDim)
                        .frame(width: 64, alignment: .leading)
                    Text("SECTOR \(run.maxSector)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(run.score)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
