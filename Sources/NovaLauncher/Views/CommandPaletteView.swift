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
        colorScheme
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
            : .white.opacity(0.58)
    }

    private var paletteBackingFill: Color {
        activeColorScheme == .dark
            ? .black.opacity(0.16)
            : .white.opacity(0.94)
    }

    private var paletteStrokeColor: Color {
        activeColorScheme == .dark
            ? .white.opacity(0.08)
            : .black.opacity(0.11)
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
        .background {
            paletteShadowBacking(cornerRadius: 24, elevation: .search)
        }
        .overlay {
            paletteSurfaceStroke(cornerRadius: 24)
        }
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
        .background {
            paletteShadowBacking(cornerRadius: 20, elevation: .results)
        }
        .overlay {
            paletteSurfaceStroke(cornerRadius: 20)
        }
    }

    private var resultsPanelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private func paletteShadowBacking(cornerRadius: CGFloat, elevation: PaletteElevation) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(paletteBackingFill)
            .shadow(
                color: .black.opacity(activeColorScheme == .dark ? 0.14 : 0.26),
                radius: activeColorScheme == .dark ? elevation.darkOuterRadius : elevation.lightOuterRadius,
                x: 0,
                y: activeColorScheme == .dark ? elevation.darkOuterOffset : elevation.lightOuterOffset
            )
            .shadow(
                color: .black.opacity(activeColorScheme == .dark ? 0.09 : 0.18),
                radius: activeColorScheme == .dark ? 12 : 16,
                x: 0,
                y: activeColorScheme == .dark ? 5 : 8
            )
            .shadow(
                color: .black.opacity(activeColorScheme == .dark ? 0.06 : 0.12),
                radius: activeColorScheme == .dark ? 7 : 9,
                x: 0,
                y: 0
            )
    }

    private func paletteSurfaceStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(paletteStrokeColor, lineWidth: activeColorScheme == .dark ? 0.5 : 1)
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
            ScrollView(.vertical, showsIndicators: false) {
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
                .padding(10)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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

private enum PaletteElevation {
    case search
    case results

    var lightOuterRadius: CGFloat {
        switch self {
        case .search:
            38
        case .results:
            42
        }
    }

    var lightOuterOffset: CGFloat {
        switch self {
        case .search:
            18
        case .results:
            20
        }
    }

    var darkOuterRadius: CGFloat {
        switch self {
        case .search:
            30
        case .results:
            28
        }
    }

    var darkOuterOffset: CGFloat {
        switch self {
        case .search:
            16
        case .results:
            14
        }
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
