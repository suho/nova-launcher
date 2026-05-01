import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var store: LauncherStore
    let dismiss: () -> Void
    let onLayoutChange: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: CommandPaletteMetrics.panelSpacing) {
            VStack(spacing: CommandPaletteMetrics.panelSpacing) {
                searchHeader

                if isExpanded {
                    resultsPanel
                }
            }
            .frame(
                width: CommandPaletteMetrics.contentWidth,
                height: CommandPaletteMetrics.contentHeight(isExpanded: isExpanded)
            )
            .preferredColorScheme(currentTheme.colorScheme)
        }
        .padding(CommandPaletteMetrics.shadowPadding)
        .frame(
            width: CommandPaletteMetrics.windowSize(isExpanded: isExpanded).width,
            height: CommandPaletteMetrics.windowSize(isExpanded: isExpanded).height
        )
        .onAppear {
            AppearanceService.apply(currentTheme)
            onLayoutChange(isExpanded)
        }
        .onChange(of: themeRawValue) { _, newValue in
            AppearanceService.apply(rawValue: newValue)
        }
        .onChange(of: isExpanded) { _, isExpanded in
            onLayoutChange(isExpanded)
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private var activeColorScheme: ColorScheme {
        currentTheme.colorScheme ?? colorScheme
    }

    private var isExpanded: Bool {
        !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var paletteShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var paletteGlass: Glass {
        .clear
            .tint(paletteSurfaceTint)
            .interactive()
    }

    private var paletteSurfaceTint: Color {
        activeColorScheme == .dark
            ? .black.opacity(0.74)
            : .white.opacity(0.36)
    }

    private var searchHeader: some View {
        HStack {
            CommandSearchField(
                text: $store.query,
                placeholder: "Search apps and commands",
                appearance: currentTheme.nsAppearance,
                onMove: { direction in
                    switch direction {
                    case .up:
                        store.moveSelection(by: -1)
                    case .down:
                        store.moveSelection(by: 1)
                    }
                },
                onSubmit: {
                    store.openSelected(completion: dismiss)
                },
                onEscape: dismiss
            )
            .frame(height: 38)
        }
        .padding(.horizontal, 26)
        .padding(.top, 2)
        .frame(width: CommandPaletteMetrics.contentWidth, height: CommandPaletteMetrics.searchBarHeight)
        .glassEffect(paletteGlass, in: paletteShape)
        .glassEffectID("command-palette-search", in: glassNamespace)
        .shadow(
            color: .black.opacity(activeColorScheme == .dark ? 0.12 : 0.035),
            radius: activeColorScheme == .dark ? 30 : 34,
            x: 0,
            y: activeColorScheme == .dark ? 16 : 14
        )
        .shadow(
            color: .black.opacity(activeColorScheme == .dark ? 0.08 : 0.025),
            radius: activeColorScheme == .dark ? 12 : 18,
            x: 0,
            y: activeColorScheme == .dark ? 5 : 4
        )
    }

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            resultsContent

            Divider()
                .opacity(0.35)

            footer
        }
        .frame(width: CommandPaletteMetrics.contentWidth, height: CommandPaletteMetrics.resultsPanelHeight)
        .glassEffect(paletteGlass, in: resultsPanelShape)
        .glassEffectID("command-palette-results", in: glassNamespace)
        .shadow(
            color: .black.opacity(activeColorScheme == .dark ? 0.10 : 0.03),
            radius: activeColorScheme == .dark ? 28 : 32,
            x: 0,
            y: activeColorScheme == .dark ? 14 : 12
        )
        .shadow(
            color: .black.opacity(activeColorScheme == .dark ? 0.07 : 0.02),
            radius: activeColorScheme == .dark ? 10 : 16,
            x: 0,
            y: activeColorScheme == .dark ? 4 : 3
        )
    }

    private var resultsPanelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if store.filteredItems.isEmpty {
            noResultsState
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ResultListScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.filteredItems) { item in
                        AppResultRow(
                            item: item,
                            subtitle: store.subtitle(for: item),
                            isSelected: item.id == store.selectedID,
                            isRunning: store.isRunning(item),
                            shortcut: store.configuration(for: item).shortcut,
                            isOpening: item.id == store.openingID
                        )
                        .id(item.id)
                        .onTapGesture {
                            store.open(item, completion: dismiss)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 24)
                .padding(.vertical, 10)
            }
            .onChange(of: store.selectedID) { _, selectedID in
                guard let selectedID else {
                    return
                }

                withAnimation(.snappy(duration: 0.12)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No Results Found")
                .font(.system(size: 18, weight: .semibold))

            Text(store.query)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            FooterShortcut(symbol: "arrow.up.arrow.down", label: "Select")
            FooterShortcut(symbol: "return", label: "Open")
            FooterShortcut(symbol: "escape", label: "Close")

            Spacer()

            if let statusMessage = store.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Local index")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct ResultListScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    private let coordinateSpaceName = "result-list-scroll-view"

    var body: some View {
        GeometryReader { viewportProxy in
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .background {
                        GeometryReader { contentProxy in
                            Color.clear.preference(
                                key: ResultListScrollMetricsPreferenceKey.self,
                                value: ResultListScrollMetrics(
                                    contentHeight: contentProxy.size.height,
                                    contentMinY: contentProxy.frame(in: .named(coordinateSpaceName)).minY
                                )
                            )
                        }
                    }
            }
            .coordinateSpace(name: coordinateSpaceName)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .overlay(alignment: .trailing) {
                ResultListScrollIndicator(
                    viewportHeight: viewportProxy.size.height,
                    contentHeight: contentHeight,
                    scrollOffset: scrollOffset,
                    colorScheme: colorScheme
                )
                .padding(.vertical, 12)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
            }
            .onPreferenceChange(ResultListScrollMetricsPreferenceKey.self) { metrics in
                contentHeight = metrics.contentHeight
                scrollOffset = max(0, -metrics.contentMinY)
            }
        }
    }
}

private struct ResultListScrollIndicator: View {
    let viewportHeight: CGFloat
    let contentHeight: CGFloat
    let scrollOffset: CGFloat
    let colorScheme: ColorScheme

    private let trackWidth: CGFloat = 4
    private let minimumThumbHeight: CGFloat = 34

    var body: some View {
        if isScrollable, trackHeight > 0 {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: trackWidth, height: trackHeight)

                Capsule()
                    .fill(thumbColor)
                    .frame(width: trackWidth, height: thumbHeight)
                    .shadow(color: thumbShadowColor, radius: 1.5, x: 0, y: 0.5)
                    .offset(y: thumbOffset)
            }
            .frame(width: 10, height: trackHeight, alignment: .top)
            .accessibilityHidden(true)
        }
    }

    private var isScrollable: Bool {
        contentHeight > viewportHeight + 1
    }

    private var trackHeight: CGFloat {
        max(0, viewportHeight - 24)
    }

    private var thumbHeight: CGFloat {
        guard contentHeight > 0 else {
            return minimumThumbHeight
        }

        return min(
            trackHeight,
            max(minimumThumbHeight, viewportHeight / contentHeight * trackHeight)
        )
    }

    private var thumbOffset: CGFloat {
        let maxScrollableOffset = max(1, contentHeight - viewportHeight)
        let maxThumbOffset = max(0, trackHeight - thumbHeight)
        let clampedOffset = min(max(scrollOffset, 0), maxScrollableOffset)

        return clampedOffset / maxScrollableOffset * maxThumbOffset
    }

    private var trackColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08)
    }

    private var thumbColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.36 : 0.24)
    }

    private var thumbShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10)
    }
}

private struct ResultListScrollMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var contentMinY: CGFloat = 0
}

private struct ResultListScrollMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = ResultListScrollMetrics()

    static func reduce(value: inout ResultListScrollMetrics, nextValue: () -> ResultListScrollMetrics) {
        value = nextValue()
    }
}

private struct FooterShortcut: View {
    let symbol: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
