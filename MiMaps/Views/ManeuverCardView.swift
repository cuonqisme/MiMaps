import SwiftUI

struct ManeuverCardView: View {
    let instruction: NavigationInstruction

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: instruction.maneuver.phoneSystemImage)
                    .font(.system(size: 48, weight: .bold))
                    .frame(width: 64)

                VStack(alignment: .leading, spacing: 2) {
                    Text(distanceText)
                        .font(.title.bold())
                    Text(roadText)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack {
                Label(
                    DurationFormatter.string(fromSeconds: instruction.remainingTimeSeconds),
                    systemImage: "clock"
                )
                Spacer()
                Label(
                    DistanceFormatter.string(fromMeters: instruction.remainingDistanceMeters),
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }

    private var distanceText: String {
        instruction.maneuver == .destination
            ? "Đã đến nơi"
            : DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters)
    }

    private var roadText: String {
        instruction.maneuver.conciseInstruction(roadName: instruction.roadName)
    }
}
