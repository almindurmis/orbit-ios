import SwiftUI
import FirebaseFirestore

// Custom segmented control: readable unselected labels on the dark backdrop.
struct PeriodPicker: View {
    @Binding var selection: LeaderboardPeriod

    var body: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardPeriod.allCases) { period in
                Button {
                    selection = period
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == period ? .black : .white.opacity(0.78))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(selection == period ? Theme.gold : Color.white.opacity(0.10),
                                    in: Capsule())
                }
            }
        }
    }
}

struct RankedEntry: Identifiable {
    let rank: Int
    let entry: LeaderboardEntry
    var id: String { entry.id }
}

// Loads a window of rows centered on the player's own entry, then pages up and
// down with Firestore cursors so huge boards are never downloaded in full.
@MainActor
final class LeaderboardModel: ObservableObject {
    enum Phase { case loading, failed, loaded }

    @Published var phase: Phase = .loading
    @Published var rows: [RankedEntry] = []
    @Published var loadingUp = false
    @Published var loadingDown = false
    @Published var hasMoreUp = false
    @Published var hasMoreDown = false
    // The player's row id when the initial window contains it; the view jumps there once.
    @Published var scrollTarget: String?

    private var period: LeaderboardPeriod = .weekly
    private var firstDoc: DocumentSnapshot?
    private var lastDoc: DocumentSnapshot?

    private let windowHalf = 20
    private let pageSize = 30

    func load(_ period: LeaderboardPeriod) async {
        self.period = period
        phase = .loading
        rows = []
        firstDoc = nil
        lastDoc = nil
        hasMoreUp = false
        hasMoreDown = false
        loadingUp = false
        loadingDown = false
        scrollTarget = nil
        do {
            if let mine = try await Backend.myEntryDocument(period) {
                let myRank = try await Backend.rank(of: mine, in: period)
                let above = try await Backend.page(period, endingBefore: mine, limit: windowHalf)
                let fromMe = try await Backend.page(period, startingAt: mine, limit: windowHalf + 1)
                let docs = above + fromMe
                let firstRank = myRank - above.count
                rows = ranked(docs, startingAt: firstRank)
                firstDoc = docs.first
                lastDoc = docs.last
                hasMoreUp = firstRank > 1
                hasMoreDown = fromMe.count == windowHalf + 1
                scrollTarget = DeviceID.id
            } else {
                let docs = try await Backend.page(period, after: nil, limit: pageSize)
                rows = ranked(docs, startingAt: 1)
                firstDoc = docs.first
                lastDoc = docs.last
                hasMoreDown = docs.count == pageSize
            }
            phase = .loaded
        } catch {
            phase = .failed
        }
    }

    func loadUp() async {
        guard !loadingUp, hasMoreUp, let cursor = firstDoc,
              let firstRank = rows.first?.rank else { return }
        loadingUp = true
        defer { loadingUp = false }
        do {
            let docs = try await Backend.page(period, endingBefore: cursor, limit: pageSize)
            let startRank = firstRank - docs.count
            rows.insert(contentsOf: ranked(docs, startingAt: startRank), at: 0)
            if let newFirst = docs.first { firstDoc = newFirst }
            hasMoreUp = startRank > 1 && !docs.isEmpty
        } catch {
            // Keep hasMoreUp so the loader retries when it appears again.
        }
    }

    func loadDown() async {
        guard !loadingDown, hasMoreDown, let cursor = lastDoc,
              let lastRank = rows.last?.rank else { return }
        loadingDown = true
        defer { loadingDown = false }
        do {
            let docs = try await Backend.page(period, after: cursor, limit: pageSize)
            rows.append(contentsOf: ranked(docs, startingAt: lastRank + 1))
            if let newLast = docs.last { lastDoc = newLast }
            hasMoreDown = docs.count == pageSize
        } catch {
            // Keep hasMoreDown so the loader retries when it appears again.
        }
    }

    private func ranked(_ docs: [DocumentSnapshot], startingAt rank: Int) -> [RankedEntry] {
        docs.enumerated().map { RankedEntry(rank: rank + $0.offset, entry: Backend.entry(from: $0.element)) }
    }
}

struct LeaderboardView: View {
    @State private var period: LeaderboardPeriod = .weekly
    @StateObject private var model = LeaderboardModel()
    @State private var didInitialScroll = false

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 16) {
                Text("LEADERBOARD")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                    .allowsHitTesting(false)
                PeriodPicker(selection: $period)
                    .padding(.horizontal, 24)
                content
            }
        }
        .task(id: period) {
            didInitialScroll = false
            await model.load(period)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !Backend.isConfigured {
            message("Leaderboard is offline.\nFirebase isn't configured in this build yet.")
        } else {
            switch model.phase {
            case .loading:
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            case .failed:
                message("Couldn't load scores.\nCheck your connection and try again.")
            case .loaded:
                if model.rows.isEmpty {
                    message("No scores yet.\nBe the first on the board!")
                } else {
                    board
                }
            }
        }
    }

    private var board: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.hasMoreUp {
                        pageLoader
                            .onAppear { loadUp(proxy) }
                    }
                    ForEach(model.rows) { ranked in
                        row(ranked)
                            .id(ranked.id)
                    }
                    if model.hasMoreDown {
                        pageLoader
                            .onAppear { Task { await model.loadDown() } }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .onAppear {
                guard let target = model.scrollTarget else {
                    didInitialScroll = true
                    return
                }
                // Next runloop so the lazy rows have a layout to jump within.
                DispatchQueue.main.async {
                    proxy.scrollTo(target, anchor: .center)
                    didInitialScroll = true
                }
            }
        }
    }

    // Prepending shifts everything down, so re-anchor the previous top row
    // to keep the visible content stable while older ranks slot in above.
    private func loadUp(_ proxy: ScrollViewProxy) {
        guard didInitialScroll else { return }
        let anchor = model.rows.first?.id
        Task {
            await model.loadUp()
            if let anchor {
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
    }

    private var pageLoader: some View {
        ProgressView()
            .tint(Theme.gold)
            .padding(12)
            .background(Color.white.opacity(0.08), in: Circle())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private func row(_ ranked: RankedEntry) -> some View {
        let entry = ranked.entry
        let isMe = entry.id == DeviceID.id
        return HStack(spacing: 14) {
            Text("\(ranked.rank)")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(ranked.rank <= 3 ? Theme.gold : Theme.textDim)
                .frame(width: 44)
            AvatarView(index: entry.avatar, size: 38)
            Text(entry.name)
                .font(.system(size: 16, weight: isMe ? .bold : .medium))
                .foregroundStyle(entry.premium ? Theme.gold : .white)
                .lineLimit(1)
            if entry.premium {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.gold)
            }
            if isMe {
                Text("YOU")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.gold, in: Capsule())
            }
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isMe ? Theme.gold.opacity(0.18) : Color.white.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func message(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
