import SwiftUI
import Charts

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    summaryCards
                    completionTrendChart
                    completionHeatmap
                    hourlyDistributionChart
                    dayOfWeekChart

                    if !appState.activityEvents.isEmpty {
                        activityFeed
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity")
            .refreshable { await appState.performFullSync() }
        }
    }

    private var filteredCompleted: [CompletedTask] {
        let cutoff = Date().daysAgo(timeRange.days)
        return appState.completedTasks.filter {
            ($0.completedDate ?? .distantPast) >= cutoff
        }
    }

    // MARK: - Summary

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Completed", value: "\(filteredCompleted.count)", icon: "checkmark.circle", color: .green)
            StatCard(title: "Daily Avg", value: String(format: "%.1f", dailyAverage), icon: "chart.bar", color: .blue)
            StatCard(title: "Best Day", value: "\(bestDayCount)", icon: "star", color: .orange, subtitle: bestDayName)
        }
        .padding(.horizontal)
    }

    private var dailyAverage: Double {
        guard !filteredCompleted.isEmpty else { return 0 }
        return Double(filteredCompleted.count) / Double(timeRange.days)
    }

    private var bestDayCount: Int {
        dailyCompletionData.map(\.count).max() ?? 0
    }

    private var bestDayName: String? {
        dailyCompletionData.max(by: { $0.count < $1.count })?.date.shortDateString
    }

    // MARK: - Completion Trend

    private var completionTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Completion Trend")

            let data = dailyCompletionData

            if data.contains(where: { $0.count > 0 }) {
                Chart(data, id: \.date) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(timeRange.days / 5, 1))) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
            } else {
                noDataPlaceholder
            }
        }
    }

    private var dailyCompletionData: [DateCount] {
        let days = timeRange.days
        let cal = Calendar.current

        return (0..<days).reversed().map { daysAgo in
            let date = cal.startOfDay(for: Date().daysAgo(daysAgo))
            let nextDay = cal.date(byAdding: .day, value: 1, to: date)!
            let count = filteredCompleted.filter {
                guard let d = $0.completedDate else { return false }
                return d >= date && d < nextDay
            }.count
            return DateCount(date: date, count: count)
        }
    }

    // MARK: - Heatmap

    private var completionHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Activity Heatmap")

            let data = dailyCompletionData
            let maxCount = max(data.map(\.count).max() ?? 1, 1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(data, id: \.date) { item in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatmapColor(count: item.count, max: maxCount))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if item.count > 0 {
                                Text("\(item.count)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(item.count > maxCount / 3 ? 1 : 0))
                            }
                        }
                }
            }
            .padding(.horizontal)

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(count: i * maxCount / 4, max: maxCount))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private func heatmapColor(count: Int, max: Int) -> Color {
        guard count > 0, max > 0 else { return Color(.systemGray5) }
        let intensity = Double(count) / Double(max)
        return Color.green.opacity(0.2 + intensity * 0.8)
    }

    // MARK: - Hourly Distribution

    private var hourlyDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Peak Hours")

            let data = hourlyData

            if data.contains(where: { $0.count > 0 }) {
                Chart(data, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", "\(item.hour)h"),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(
                        item.hour == peakHour ? Color.orange : Color.blue.opacity(0.6)
                    )
                    .cornerRadius(3)
                }
                .frame(height: 140)
                .padding(.horizontal)

                if let peak = peakHour {
                    Text("Most productive hour: \(peak):00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            } else {
                noDataPlaceholder
            }
        }
    }

    private var hourlyData: [HourCount] {
        var counts = Array(repeating: 0, count: 24)
        for task in filteredCompleted {
            if let date = task.completedDate {
                counts[date.hourOfDay] += 1
            }
        }
        return (6..<24).map { HourCount(hour: $0, count: counts[$0]) }
            + (0..<6).map { HourCount(hour: $0, count: counts[$0]) }
    }

    private var peakHour: Int? {
        hourlyData.max(by: { $0.count < $1.count })?.hour
    }

    // MARK: - Day of Week

    private var dayOfWeekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Day of Week")

            let data = dayOfWeekData

            if data.contains(where: { $0.count > 0 }) {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .padding(.horizontal)
            } else {
                noDataPlaceholder
            }
        }
    }

    private var dayOfWeekData: [DayOfWeekCount] {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var counts = Array(repeating: 0, count: 7)

        for task in filteredCompleted {
            if let date = task.completedDate {
                counts[date.weekdayIndex] += 1
            }
        }

        return (0..<7).map { DayOfWeekCount(day: dayNames[$0], count: counts[$0]) }
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Events")

            LazyVStack(spacing: 0) {
                ForEach(appState.activityEvents.prefix(20)) { event in
                    ActivityRow(event: event)
                    if event.id != appState.activityEvents.prefix(20).last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var noDataPlaceholder: some View {
        Text("No data for this period")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - Data Types

struct DateCount {
    let date: Date
    let count: Int
}

struct HourCount {
    let hour: Int
    let count: Int
}

struct DayOfWeekCount {
    let day: String
    let count: Int
}
