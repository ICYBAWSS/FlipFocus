import SwiftUI
import PhotosUI

struct ThemeMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var themeToEdit: CustomTheme?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose wisely")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundColor(.secondary)
                        Text("Themes")
                            .font(.system(size: 48, weight: .bold, design: .default))
                    }
                    .padding(.horizontal, 24)

                    // 1. Built-in Themes
                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Built-in").padding(.horizontal, 24)
                        VStack(spacing: 10) {
                            ForEach(ThemeType.allCases) { theme in
                                ThemePreviewCard(theme: theme, 
                                               isSelected: stopwatch.themeManager.currentTheme == theme) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        stopwatch.themeManager.selectTheme(theme)
                                    }
                                }
                            }
                        }
                    }

                    // 2. Custom Themes
                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Your Themes").padding(.horizontal, 24)
                        VStack(spacing: 10) {
                            ForEach(stopwatch.themeManager.customThemes) { theme in
                                CustomThemePreviewCard(
                                    theme: theme, 
                                    isSelected: stopwatch.themeManager.selectedCustomThemeID == theme.id,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            stopwatch.themeManager.selectCustomTheme(theme)
                                        }
                                    },
                                    onEdit: {
                                        themeToEdit = theme
                                    }
                                )
                            }
                            
                            // Create New Theme Button
                            Button(action: {
                                let newTheme = stopwatch.themeManager.addNewCustomTheme()
                                themeToEdit = newTheme
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create New Theme")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
            .sheet(item: $themeToEdit) { theme in
                CustomThemeEditor(stopwatch: stopwatch, themeID: theme.id)
            }
        }
    }
}

struct CustomThemePreviewCard: View {
    let theme: CustomTheme
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Tap to select, edit to customize")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(.blue)
                }
                
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(10)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
            }
            .padding(16)
            .glassCard(tint: isSelected ? Color.blue.opacity(0.04) : .clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomThemeEditor: View {
    @ObservedObject var stopwatch: StopwatchManager
    let themeID: UUID
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    
    // Binding to the specific theme in the manager
    private var themeIndex: Int? {
        stopwatch.themeManager.customThemes.firstIndex(where: { $0.id == themeID })
    }

    private var themeName: Binding<String> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return "" }
                return stopwatch.themeManager.customThemes[idx].name 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].name = $0
                stopwatch.themeManager.save()
            }
        )
    }

    private var secColor: Binding<Color> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return .blue }
                return stopwatch.themeManager.customThemes[idx].settings.color(for: stopwatch.themeManager.customThemes[idx].settings.ringColorSeconds) 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].settings.ringColorSeconds = $0.toComponents()
                stopwatch.themeManager.save()
            }
        )
    }
    
    private var minColor: Binding<Color> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return .green }
                return stopwatch.themeManager.customThemes[idx].settings.color(for: stopwatch.themeManager.customThemes[idx].settings.ringColorMinutes) 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].settings.ringColorMinutes = $0.toComponents()
                stopwatch.themeManager.save()
            }
        )
    }
    
    private var hrColor: Binding<Color> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return .red }
                return stopwatch.themeManager.customThemes[idx].settings.color(for: stopwatch.themeManager.customThemes[idx].settings.ringColorHours) 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].settings.ringColorHours = $0.toComponents()
                stopwatch.themeManager.save()
            }
        )
    }
    
    private var accentColor: Binding<Color> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return .white }
                return stopwatch.themeManager.customThemes[idx].settings.color(for: stopwatch.themeManager.customThemes[idx].settings.mainAccentColor) 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].settings.mainAccentColor = $0.toComponents()
                stopwatch.themeManager.save()
            }
        )
    }

    private var isLightMode: Binding<Bool> {
        Binding(
            get: { 
                guard let idx = themeIndex else { return false }
                return stopwatch.themeManager.customThemes[idx].settings.isLightMode 
            },
            set: { 
                guard let idx = themeIndex else { return }
                stopwatch.themeManager.customThemes[idx].settings.isLightMode = $0
                stopwatch.themeManager.save()
            }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Theme Identity") {
                    TextField("Theme Name", text: themeName)
                }
                
                Section("Background Image") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo")
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                stopwatch.themeManager.saveCustomImage(data: data, for: themeID)
                            }
                        }
                    }

                    if let idx = themeIndex, stopwatch.themeManager.customThemes[idx].settings.backgroundImageFileName != nil {
                        Button("Remove Photo", role: .destructive) {
                            stopwatch.themeManager.deleteCustomImage(for: themeID)
                        }
                    }
                }

                Section("Ring Colors") {
                    ColorPicker("Seconds Ring", selection: secColor)
                    ColorPicker("Minutes Ring", selection: minColor)
                    ColorPicker("Hours Ring", selection: hrColor)
                }

                Section("Appearance") {
                    ColorPicker("Accent Color", selection: accentColor)
                    Toggle("Light Mode Text", isOn: isLightMode)
                }
                
                Section {
                    Button("Delete Theme", role: .destructive) {
                        if let idx = themeIndex {
                            stopwatch.themeManager.deleteCustomTheme(stopwatch.themeManager.customThemes[idx])
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Customize")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

extension Color {
    func toComponents() -> [Double] {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
}

struct ThemePreviewCard: View {
    let theme: ThemeType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(previewBg)
                        .frame(width: 64, height: 64)
                    previewIcon
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                    Text(themeDescription)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(.blue)
                }
            }
            .padding(16)
            .glassCard(tint: isSelected ? Color.blue.opacity(0.04) : .clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var previewBg: Color {
        switch theme {
        case .ascii, .minimal: return .black
        case .asciiLight, .minimalLight: return Color(red: 253/255, green: 251/255, blue: 212/255)
        }
    }

    @ViewBuilder private var previewIcon: some View {
        switch theme {
        case .ascii, .asciiLight:
            Text("01").font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(theme.isLight ? .black.opacity(0.7) : .white.opacity(0.8))
        case .minimal, .minimalLight:
            ZStack {
                Circle().stroke(theme.isLight ? Color.black.opacity(0.15) : Color.white.opacity(0.2), lineWidth: 1.5).frame(width: 28, height: 28)
                Circle().trim(from: 0, to: 0.65)
                    .stroke(theme.isLight ? Color.black.opacity(0.6) : Color.white, lineWidth: 2)
                    .frame(width: 28, height: 28).rotationEffect(.degrees(-90))
            }
        }
    }

    private var themeDescription: String {
        switch theme {
        case .ascii:       return "Cool ASCII art inspired theme"
        case .asciiLight:  return "ASCII but on a cream backround"
        case .minimal:     return "No Nonsense"
        case .minimalLight: return "Simple on that southing cream backround"
        }
    }
}
