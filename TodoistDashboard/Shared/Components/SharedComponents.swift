import SwiftUI

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Detailed Stat Card

struct DetailedStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                
                Spacer()
            }
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Int

    var body: some View {
        Text(AppTheme.priorityLabel(for: priority))
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.priorityColor(for: priority))
            .clipShape(Capsule())
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    var lineWidth: CGFloat = 6
    var color: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    var color: Color = .blue
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(progress, 1.0)))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Avatar Circle

struct AvatarCircle: View {
    let initials: String
    var size: CGFloat = 36
    var color: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            if let action {
                Button(action: action) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Loading View

struct LoadingOverlay: View {
    var message: String = "Syncing..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sync Status Bar

struct SyncStatusBar: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 6) {
            switch state {
            case .idle:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.secondary)
                Text("Not synced")
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing...")
            case .retrying(let attempt):
                ProgressView()
                    .scaleEffect(0.7)
                Text("Retrying (\(attempt))...")
            case .synced(let date):
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
                Text("Synced \(date.relativeString)")
            case .error(let msg):
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
                Text(msg)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
