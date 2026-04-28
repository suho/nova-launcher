import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var store: LauncherStore
    let dismiss: () -> Void
    let onLayoutChange: (Bool) -> Void

    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue

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
            onLayoutChange(isExpanded)
        }
        .onChange(of: isExpanded) { _, isExpanded in
            onLayoutChange(isExpanded)
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private var isExpanded: Bool {
        !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var paletteShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var searchHeader: some View {
        HStack {
            CommandSearchField(
                text: $store.query,
                placeholder: "Search apps",
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
        .frame(width: CommandPaletteMetrics.contentWidth, height: CommandPaletteMetrics.searchBarHeight)
        .glassEffect(.regular.interactive(), in: paletteShape)
        .clipShape(paletteShape)
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 12)
    }

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            resultsContent

            Divider()
                .opacity(0.35)

            footer
        }
        .frame(width: CommandPaletteMetrics.contentWidth, height: CommandPaletteMetrics.resultsPanelHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if store.filteredApplications.isEmpty {
            noResultsState
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.filteredApplications) { application in
                        AppResultRow(
                            application: application,
                            isSelected: application.id == store.selectedID,
                            isOpening: application.id == store.openingID
                        )
                        .id(application.id)
                        .onTapGesture {
                            store.open(application, completion: dismiss)
                        }
                    }
                }
                .padding(10)
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

            Text("No Apps Found")
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

            if let lastOpenedName = store.lastOpenedName {
                Text("Opened \(lastOpenedName)")
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
