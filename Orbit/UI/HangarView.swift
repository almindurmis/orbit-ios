import SwiftUI
import SpriteKit

// The Hangar: pick your orbiter's look and trail color. Everything unlocks by
// pilot level; locked entries show their level. Selections persist instantly —
// the scene restyles when the sheet closes.
struct HangarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ship = Progress.selectedShip
    @State private var trailLevel = Progress.selectedTrailLevel

    private let pilotLevel = Progress.level
    private let shipColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var trailColor: Color {
        let chosen = Progress.trailTiers.first(where: { $0.level == trailLevel })?.color
        let auto = Progress.trailTiers.last(where: { pilotLevel >= $0.level })?.color
        return Color(uiColor: chosen ?? auto ?? .white)
    }

    var body: some View {
        ZStack {
            GalaxyBackground()
            VStack(spacing: 20) {
                Text("HANGAR")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                Text("PILOT LV \(pilotLevel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.gold)

                preview
                    .padding(.vertical, 6)

                section("SHIP") {
                    LazyVGrid(columns: shipColumns, spacing: 12) {
                        ForEach(ShipStyle.allCases, id: \.self) { style in
                            shipTile(style)
                        }
                    }
                }

                section("TRAIL") {
                    HStack(spacing: 14) {
                        ForEach(Progress.trailTiers, id: \.level) { tier in
                            trailSwatch(tier)
                        }
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 60)
                        .background(Theme.gold, in: Capsule())
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }

    // A live mock of the orbiter: ring, styled core, and a trail arc behind it.
    private var preview: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: Palette.cyan).opacity(0.7), lineWidth: 2)
                .frame(width: 110, height: 110)
            TrailArc()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [trailColor.opacity(0), trailColor]),
                        center: .center,
                        startAngle: .degrees(150),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 110, height: 110)
            shipDot(ship, size: 17)
                .offset(y: -55)
        }
        .frame(height: 130)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textDim)
            content()
        }
    }

    private func shipTile(_ style: ShipStyle) -> some View {
        let unlocked = pilotLevel >= style.unlockLevel
        let selected = ship == style
        return Button {
            guard unlocked else { return }
            ship = style
            Progress.selectedShip = style
        } label: {
            VStack(spacing: 6) {
                shipDot(style, size: 15)
                    .frame(height: 26)
                Text(style.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(unlocked ? .white : Theme.textDim)
                Text(unlocked ? " " : "LV \(style.unlockLevel)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Theme.gold : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textDim)
                        .padding(6)
                }
            }
            .opacity(unlocked ? 1 : 0.55)
        }
    }

    private func trailSwatch(_ tier: (level: Int, color: SKColor)) -> some View {
        let unlocked = pilotLevel >= tier.level
        let selected = trailLevel == tier.level
            || (trailLevel == 0 && tier.level == autoTrailLevel)
        return Button {
            guard unlocked else { return }
            trailLevel = tier.level
            Progress.selectedTrailLevel = tier.level
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(Color(uiColor: tier.color))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(selected ? Theme.gold : .white.opacity(0.15),
                                             lineWidth: selected ? 2.5 : 1))
                    .overlay {
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.black.opacity(0.65))
                        }
                    }
                    .opacity(unlocked ? 1 : 0.45)
                Text(unlocked ? " " : "\(tier.level)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
            }
        }
    }

    private var autoTrailLevel: Int {
        Progress.trailTiers.last(where: { pilotLevel >= $0.level })?.level ?? 1
    }

    @ViewBuilder
    private func shipDot(_ style: ShipStyle, size: CGFloat) -> some View {
        let core = Color(uiColor: style.coreColor)
        let halo = Color(uiColor: style.haloColor)
        ZStack {
            Circle()
                .fill(halo.opacity(0.55))
                .frame(width: size * 2.3, height: size * 2.3)
                .blur(radius: size * 0.45)
            if style == .crystal {
                DiamondShape()
                    .fill(core)
                    .frame(width: size, height: size * 1.35)
            } else if style == .void {
                Circle()
                    .fill(core)
                    .overlay(Circle().stroke(halo, lineWidth: 2))
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(core)
                    .frame(width: size, height: size)
            }
        }
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct TrailArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: rect.width / 2,
                    startAngle: .degrees(155),
                    endAngle: .degrees(268),
                    clockwise: false)
        return path
    }
}
