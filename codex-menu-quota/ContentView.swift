import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: QuotaStore
    @Bindable var preferences: AppPreferences
    @State private var page: Page = .overview

    private enum Page {
        case overview
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if page == .overview {
                ScrollView {
                    VStack(spacing: 14) {
                        if let message = store.errorMessage {
                            errorBanner(message)
                        }

                        if let limits = store.response?.codexLimits {
                            usageCard(limits)
                        } else if store.isRefreshing {
                            ProgressView("正在读取 Codex 额度…")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            emptyState
                        }

                        if let resets = store.response?.rateLimitResetCredits {
                            resetCreditsCard(resets)
                        }
                    }
                    .padding(16)
                }
            } else {
                SettingsView(preferences: preferences, store: store)
            }

            footer
        }
        .frame(width: 430, height: panelHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { store.start() }
    }

    private var panelHeight: CGFloat {
        let resetCount = store.response?.rateLimitResetCredits?.sortedCredits.count ?? 0
        return resetCount == 3 ? 580 : 560
    }

    private var header: some View {
        HStack(spacing: 12) {
            if page == .settings {
                Button {
                    page = .overview
                } label: {
                    ZStack {
                        Circle().fill(.quaternary)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(page == .overview ? "Codex 额度" : "设置")
                    .font(.headline)
                Text(page == .overview ? statusSubtitle : "菜单栏与刷新偏好")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if page == .overview, let plan = store.response?.codexLimits.planType {
                Text(plan.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.mint.opacity(0.18), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var statusSubtitle: String {
        if store.isRefreshing { return "正在刷新…" }
        if let date = store.lastUpdated {
            return "更新于 \(QuotaFormatters.time.string(from: date))"
        }
        return "等待首次同步"
    }

    private func usageCard(_ limits: RateLimitSnapshot) -> some View {
        HStack(spacing: 12) {
            if let primary = limits.primary {
                quotaCard(title: "5 小时额度", window: primary, resetFormat: .time)
            }
            if let secondary = limits.secondary {
                quotaCard(title: "每周额度", window: secondary, resetFormat: .date)
            }
        }
    }

    private enum ResetDateStyle { case time, date }

    private func quotaCard(title: String, window: RateLimitWindow, resetFormat: ResetDateStyle) -> some View {
        let progress = min(max(Double(window.remainingPercent) / 100, 0), 1)
        let tint = color(for: window.remainingPercent)

        return VStack(spacing: 11) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: -1) {
                    Text("\(window.remainingPercent)%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                    Text("剩余")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 74, height: 74)

            if let date = window.resetDate {
                Text("\(resetFormat == .time ? QuotaFormatters.time.string(from: date) : QuotaFormatters.date.string(from: date)) 重置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 158)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func color(for remaining: Int) -> Color {
        if remaining <= 15 { return .red }
        if remaining <= 35 { return .orange }
        return .green
    }

    private func resetCreditsCard(_ summary: ResetCreditsSummary) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("使用限额重置").font(.system(size: 15, weight: .semibold))
                    if let nearest = summary.nearestExpiry {
                        Text("最近一张将于 \(QuotaFormatters.dateTime.string(from: nearest)) 到期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("可用 \(summary.availableCount) 次")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.mint.opacity(0.2), in: Capsule())
            }
            .padding(16)

            ForEach(summary.sortedCredits) { credit in
                Divider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(credit.title ?? "Codex 额度重置")
                            .font(.subheadline.weight(.medium))
                        if let expiry = credit.expiryDate {
                            Text("将于 \(QuotaFormatters.date.string(from: expiry)) 到期")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "暂时没有额度数据",
            systemImage: "gauge.open.with.lines.needle.33percent",
            description: Text("请确认 Codex 已安装并使用 ChatGPT 账号登录。")
        )
        .frame(minHeight: 150)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if page == .overview {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

                Button {
                    page = .settings
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }

            Spacer()

            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

struct MenuBarLabel: View {
    @Bindable var store: QuotaStore
    @Bindable var preferences: AppPreferences

    var body: some View {
        Label {
            Text(preferences.menuBarText(for: store.response))
        } icon: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
        }
        .labelStyle(.titleAndIcon)
        .task { store.start() }
    }
}

#Preview {
    let preferences = AppPreferences()
    ContentView(store: QuotaStore(preferences: preferences), preferences: preferences)
}
