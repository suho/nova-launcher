import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var store: LauncherStore
    let dismiss: () -> Void
    let openSettings: () -> Void
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
        .padding(.horizontal, CommandPaletteMetrics.shadowHorizontalPadding)
        .padding(.top, CommandPaletteMetrics.shadowTopPadding)
        .padding(.bottom, CommandPaletteMetrics.shadowBottomPadding)
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
        if activeColorScheme == .dark {
            return .clear
                .tint(paletteSurfaceTint)
                .interactive()
        }

        return .clear
            .tint(paletteSurfaceTint)
            .interactive()
    }

    private var paletteSurfaceTint: Color {
        activeColorScheme == .dark
            ? .black.opacity(0.74)
            : .white.opacity(0.34)
    }

    private var paletteStrokeGradient: LinearGradient {
        let topColor = activeColorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.48)
        let middleColor = activeColorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.white.opacity(0.18)
        let bottomColor = activeColorScheme == .dark
            ? Color.clear
            : Color.black.opacity(0.07)

        return LinearGradient(
            stops: [
                .init(color: topColor, location: 0),
                .init(color: middleColor, location: 0.56),
                .init(color: bottomColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
                onEscape: dismiss,
                onOpenSettings: openSettings
            )
            .frame(height: 38)
        }
        .padding(.horizontal, 26)
        .padding(.top, 2)
        .frame(width: CommandPaletteMetrics.contentWidth, height: CommandPaletteMetrics.searchBarHeight)
        .glassEffect(paletteGlass, in: paletteShape)
        .glassEffectID("command-palette-search", in: glassNamespace)
        .background {
            paletteShadowBacking(
                cornerRadius: 24,
                elevation: .search,
                outset: searchShadowOutset
            )
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
            paletteShadowBacking(
                cornerRadius: 20,
                elevation: .results,
                outset: resultsShadowOutset
            )
        }
        .overlay {
            paletteSurfaceStroke(cornerRadius: 20)
        }
    }

    private var resultsPanelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private func paletteShadowBacking(
        cornerRadius: CGFloat,
        elevation: PaletteElevation,
        outset: PaletteShadowOutset
    ) -> some View {
        ZStack {
            PaletteDropShadowView(
                cornerRadius: cornerRadius,
                shadows: shadowLayers(for: elevation),
                outset: outset
            )
            .padding(.horizontal, -outset.horizontal)
            .padding(.top, -outset.top)
            .padding(.bottom, -outset.bottom)

            if activeColorScheme == .dark {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.16))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.06))
            }
        }
    }

    private func paletteSurfaceStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(paletteStrokeGradient, lineWidth: activeColorScheme == .dark ? 0.5 : 1)
    }

    private func shadowLayers(for elevation: PaletteElevation) -> [PaletteShadowLayer] {
        if activeColorScheme == .dark {
            return [
                PaletteShadowLayer(opacity: 0.14, radius: elevation.darkOuterRadius, y: elevation.darkOuterOffset),
                PaletteShadowLayer(opacity: 0.09, radius: 12, y: 5),
                PaletteShadowLayer(opacity: 0.06, radius: 7, y: 0)
            ]
        }

        return [
            PaletteShadowLayer(opacity: 0.13, radius: elevation.lightOuterRadius, y: elevation.lightOuterOffset),
            PaletteShadowLayer(opacity: 0.10, radius: 42, y: 20),
            PaletteShadowLayer(opacity: 0.055, radius: 56, y: 0)
        ]
    }

    private var searchShadowOutset: PaletteShadowOutset {
        PaletteShadowOutset(
            horizontal: CommandPaletteMetrics.searchShadowHorizontalPadding,
            top: CommandPaletteMetrics.shadowTopPadding,
            bottom: CommandPaletteMetrics.shadowBottomPadding
        )
    }

    private var resultsShadowOutset: PaletteShadowOutset {
        PaletteShadowOutset(
            horizontal: CommandPaletteMetrics.resultsShadowHorizontalPadding,
            top: CommandPaletteMetrics.shadowTopPadding,
            bottom: CommandPaletteMetrics.shadowBottomPadding
        )
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            86
        case .results:
            92
        }
    }

    var lightOuterOffset: CGFloat {
        switch self {
        case .search:
            34
        case .results:
            36
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

private struct PaletteShadowLayer: Equatable {
    let opacity: Float
    let radius: CGFloat
    let y: CGFloat
}

private struct PaletteShadowOutset: Equatable {
    let horizontal: CGFloat
    let top: CGFloat
    let bottom: CGFloat
}

private struct PaletteDropShadowView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let shadows: [PaletteShadowLayer]
    let outset: PaletteShadowOutset

    func makeNSView(context: Context) -> PaletteDropShadowHostView {
        let view = PaletteDropShadowHostView()
        view.update(cornerRadius: cornerRadius, shadows: shadows, outset: outset)
        return view
    }

    func updateNSView(_ nsView: PaletteDropShadowHostView, context: Context) {
        nsView.update(cornerRadius: cornerRadius, shadows: shadows, outset: outset)
    }
}

private final class PaletteDropShadowHostView: NSView {
    private var cornerRadius: CGFloat = 0
    private var shadows: [PaletteShadowLayer] = []
    private var outset = PaletteShadowOutset(horizontal: 0, top: 0, bottom: 0)
    private var shadowLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(cornerRadius: CGFloat, shadows: [PaletteShadowLayer], outset: PaletteShadowOutset) {
        guard self.cornerRadius != cornerRadius || self.shadows != shadows || self.outset != outset else {
            return
        }

        self.cornerRadius = cornerRadius
        self.shadows = shadows
        self.outset = outset
        rebuildShadowLayers()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        updateShadowLayerFrames()
    }

    private func rebuildShadowLayers() {
        shadowLayers.forEach { $0.removeFromSuperlayer() }
        shadowLayers = shadows.map { shadow in
            let shadowLayer = CALayer()
            shadowLayer.isOpaque = false
            shadowLayer.masksToBounds = false
            shadowLayer.backgroundColor = NSColor.clear.cgColor
            shadowLayer.shadowColor = NSColor.black.cgColor
            shadowLayer.shadowOpacity = shadow.opacity
            shadowLayer.shadowRadius = shadow.radius
            shadowLayer.shadowOffset = CGSize(width: 0, height: -shadow.y)
            layer?.addSublayer(shadowLayer)
            return shadowLayer
        }
        updateShadowLayerFrames()
    }

    private func updateShadowLayerFrames() {
        let surfaceRect = NSRect(
            x: bounds.minX + outset.horizontal,
            y: bounds.minY + outset.bottom,
            width: max(0, bounds.width - outset.horizontal * 2),
            height: max(0, bounds.height - outset.top - outset.bottom)
        )
        let shadowPath = CGPath(
            roundedRect: surfaceRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        for shadowLayer in shadowLayers {
            shadowLayer.frame = bounds
            shadowLayer.cornerRadius = cornerRadius
            shadowLayer.shadowPath = shadowPath
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
