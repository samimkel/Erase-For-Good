import SwiftUI
import Foundation
import AppKit

// MARK: - Data Model
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let path: String
    var isSelected: Bool = false
    
    // Hierarchy properties
    var level: Int = 0
    var hasChildren: Bool = false
    var isExpanded: Bool = false
    var isHidden: Bool = false
    var parentId: UUID? = nil
}

// MARK: - Custom Colors
extension Color {
    static let accentBlue = Color(red: 0.1, green: 0.45, blue: 0.85)
    static let dangerRed = Color(red: 0.85, green: 0.25, blue: 0.3)
    static let cardBackground = Color(NSColor.textBackgroundColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
}

// MARK: - Main View
struct ContentView: View {
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var isDeepScan = false
    @State private var enableGrouping = false
    @State private var statusMessage = "Ready to search."
    @State private var animateBackground = false
    @State private var hasFullDiskAccess = false
    
    // Detects if we are running in the Xcode Canvas Preview
    var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    // Detects if the App Sandbox is still turned on
    var isSandboxed: Bool {
        NSHomeDirectory().contains("Containers")
    }
    
    var body: some View {
        ZStack {
            // MARK: Sweet Animated Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentBlue.opacity(0.15),
                    Color(NSColor.windowBackgroundColor),
                    Color.dangerRed.opacity(0.08),
                    Color.accentBlue.opacity(0.05)
                ]),
                startPoint: animateBackground ? .topLeading : .bottomLeading,
                endPoint: animateBackground ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: animateBackground)
            .onAppear {
                animateBackground = true
                checkFullDiskAccess()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                checkFullDiskAccess()
            }
            
            VStack(spacing: 0) {
                // MARK: Premium Header
                HStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.accentBlue.opacity(0.8), .accentBlue]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .shadow(color: .accentBlue.opacity(0.3), radius: 5, x: 0, y: 3)
                        
                        Image(systemName: "trash")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Erase For Good")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Scan. Select. Destroy.")
                            .font(.title3)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 35)
                .padding(.bottom, 25)
                .background(.regularMaterial)
                
                // MARK: Warning Banners
                if isPreview {
                    Text("⚠️ You are in the Preview. Press Cmd + R to run the real app!")
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white).padding(.vertical, 8).frame(maxWidth: .infinity).background(Color.dangerRed)
                } else if isSandboxed {
                    Text("🛑 APP SANDBOX IS ON! Go to Xcode > your project > Signing & Capabilities and delete 'App Sandbox'.")
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white).padding(.vertical, 8).frame(maxWidth: .infinity).background(Color.dangerRed)
                }
                
                // MARK: Full Disk Access Warning Banner
                if isDeepScan && !hasFullDiskAccess && !isPreview && !isSandboxed {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Disk Access Required")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Without this, macOS blocks the Deep Scan from finding Library caches.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button(action: openPrivacySettings) {
                            Text("Open Settings")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .shadow(color: Color.accentBlue.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .padding(14)
                    .background(Color.accentBlue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentBlue.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // MARK: Search Area
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(isSearching ? .accentBlue : .primary)
                            
                            TextField("Enter app name (e.g., 'Spotify')", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .onSubmit { performSearch() }
                                .disabled(isSearching)
                            
                            if !searchText.isEmpty && !isSearching {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondaryText)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .transition(.opacity)
                            }
                        }
                        .padding(14)
                        .background(Color.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        if isSearching {
                            ProgressView().scaleEffect(0.8).padding(.leading, 12)
                        }
                    }
                    
                    HStack {
                        // Scan Type Toggle
                        Picker("Scan Type", selection: $isDeepScan) {
                            Text("Standard Scan (Fast)").tag(false)
                            Text("Deep Scan (Thorough)").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 300)
                        
                        Spacer()
                        
                        // Grouping Toggle
                        Toggle("Group by Folder (Tree View)", isOn: $enableGrouping)
                            .toggleStyle(.checkbox)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                    .disabled(isSearching)
                    
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(statusMessage.contains("Error") ? .dangerRed : .secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 5)
                        .animation(.easeInOut, value: statusMessage)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                .background(.regularMaterial)
                
                Divider()
                
                // MARK: Beautiful Results Area
                ZStack {
                    if results.isEmpty && !isSearching {
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 70))
                                .foregroundColor(.secondaryText.opacity(0.5))
                            Text(statusMessage == "Ready to search." ? "Awaiting your command." : "No remnants found.")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(results) { result in
                                    if !result.isHidden {
                                        FileCardView(
                                            result: result,
                                            onToggleSelection: { toggleSelection(for: result.id) },
                                            onToggleExpand: { toggleExpand(for: result.id) }
                                        )
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                            .padding(25)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // MARK: Action Bar
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            for i in results.indices { results[i].isSelected = true }
                        }
                    }) {
                        Label("Select All", systemImage: "checkmark.square.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(results.isEmpty)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            for i in results.indices { results[i].isSelected = false }
                        }
                    }) {
                        Label("Deselect All", systemImage: "square")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(results.isEmpty)
                    
                    Spacer()
                    
                    Button(action: trashSelectedFiles) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.title3)
                            Text("Move to Trash")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(results.filter { $0.isSelected }.isEmpty ? Color.gray.opacity(0.3) : Color.dangerRed)
                        .foregroundColor(results.filter { $0.isSelected }.isEmpty ? .secondaryText : .white)
                        .cornerRadius(12)
                        .shadow(color: results.filter { $0.isSelected }.isEmpty ? .clear : Color.dangerRed.opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(results.filter { $0.isSelected }.isEmpty)
                    .animation(.spring(), value: results.filter { $0.isSelected }.isEmpty)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(.regularMaterial)
            }
        }
        .frame(minWidth: 750, minHeight: 600)
    }
    
    // MARK: - Core Interactions
    private func toggleSelection(for id: UUID) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        let newState = !results[index].isSelected
        
        withAnimation(.easeInOut(duration: 0.15)) {
            results[index].isSelected = newState
            
            let parentLevel = results[index].level
            for i in (index + 1)..<results.count {
                if results[i].level > parentLevel {
                    results[i].isSelected = newState
                } else {
                    break
                }
            }
        }
    }
    
    // MARK: - Permissions
    private func checkFullDiskAccess() {
        // Checking Safari Bookmarks is a much more reliable test for Full Disk Access in macOS 13+
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: path)
    }
    
    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func toggleExpand(for id: UUID) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            results[index].isExpanded.toggle()
            updateVisibility()
        }
    }
    
    private func updateVisibility() {
        var activeCollapseLevel = -1
        for i in 0..<results.count {
            let item = results[i]
            if activeCollapseLevel != -1 {
                if item.level > activeCollapseLevel {
                    results[i].isHidden = true
                    continue
                } else {
                    activeCollapseLevel = -1
                }
            }
            results[i].isHidden = false
            if item.hasChildren && !item.isExpanded {
                activeCollapseLevel = item.level
            }
        }
    }
    
    // MARK: - Search Logic
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            statusMessage = "Please type at least 2 characters to search safely."
            return
        }
        
        let safeQuery = query.replacingOccurrences(of: "'", with: "")
        let useGrouping = enableGrouping
        
        isSearching = true
        withAnimation { results.removeAll() }
        statusMessage = isDeepScan ? "Deep scanning (this may take 10-30 seconds)..." : "Quickly searching your Mac for '\(safeQuery)'..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var rawPaths: [String] = []
            let task = Process()
            let pipe = Pipe()
            
            if self.isDeepScan {
                // MARK: Fixed Deep Scan Shell Script (Surgical Strike)
                // We explicitly target app remnant folders and AVOID sensitive folders like ~/Library/Photos or iCloud
                let home = NSHomeDirectory()
                let targetDirs = [
                    "/Applications",
                    "'\(home)/Library/Application Support'",
                    "'\(home)/Library/Caches'",
                    "'\(home)/Library/Preferences'",
                    "'\(home)/Library/Logs'",
                    "'\(home)/Library/Containers'",
                    "'\(home)/Library/Saved Application State'",
                    "'/Library/Application Support'",
                    "'/Library/Caches'",
                    "'/Library/Preferences'",
                    "'/Library/Logs'"
                ].joined(separator: " ")
                
                let shellScript = "find \(targetDirs) -iname '*\(safeQuery)*' 2>/dev/null"
                
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
                task.arguments = ["-c", shellScript]
                task.standardOutput = pipe
                
                do {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        rawPaths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.statusMessage = "Error running shell scan: \(error.localizedDescription)"
                        self.isSearching = false
                    }
                    return
                }
            } else {
                task.standardError = FileHandle.nullDevice
                task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
                task.arguments = ["kMDItemFSName == '*\(safeQuery)*'cd"]
                task.standardOutput = pipe
                
                do {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        rawPaths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.statusMessage = "Error running scan: \(error.localizedDescription)"
                        self.isSearching = false
                    }
                    return
                }
            }
            
            let sortedPaths = rawPaths.sorted()
            var newResults: [SearchResult] = []
            
            if useGrouping {
                var parentStack: [(path: String, id: UUID, level: Int)] = []
                for path in sortedPaths {
                    while let last = parentStack.last, !path.hasPrefix(last.path + "/") {
                        parentStack.removeLast()
                    }
                    let level = parentStack.count
                    let parentId = parentStack.last?.id
                    
                    var item = SearchResult(path: path)
                    item.level = level
                    item.parentId = parentId
                    
                    newResults.append(item)
                    
                    if let pid = parentId, let pIndex = newResults.firstIndex(where: { $0.id == pid }) {
                        newResults[pIndex].hasChildren = true
                    }
                    parentStack.append((path: path, id: item.id, level: level))
                }
            } else {
                newResults = sortedPaths.map { SearchResult(path: $0) }
            }
            
            DispatchQueue.main.async {
                self.results = newResults
                if useGrouping {
                    self.updateVisibility()
                }
                self.statusMessage = self.isDeepScan ? "Deep scan complete. Found \(self.results.count) items." : "Standard scan complete. Found \(self.results.count) items."
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Trashing Logic
    private func trashSelectedFiles() {
        let selectedPaths = results.filter { $0.isSelected }.map { $0.path }.sorted()
        guard !selectedPaths.isEmpty else { return }
        
        var topLevelPathsToTrash: [String] = []
        for path in selectedPaths {
            let isChildOfAlreadyTrashingItem = topLevelPathsToTrash.contains { root in
                path.hasPrefix(root + "/")
            }
            if !isChildOfAlreadyTrashingItem {
                topLevelPathsToTrash.append(path)
            }
        }
        
        let urlsToTrash = topLevelPathsToTrash.map { URL(fileURLWithPath: $0) }
        statusMessage = "Moving \(urlsToTrash.count) top-level items to Trash..."
        
        NSWorkspace.shared.recycle(urlsToTrash) { trashedURLs, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.statusMessage = "Error moving files: \(error.localizedDescription)"
                } else {
                    let trashedCount = trashedURLs.count
                    self.statusMessage = "Successfully moved \(trashedCount) items to Trash."
                    
                    withAnimation {
                        self.results.removeAll { result in
                            selectedPaths.contains(result.path)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Custom Card View for Results
struct FileCardView: View {
    let result: SearchResult
    let onToggleSelection: () -> Void
    let onToggleExpand: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            if result.level > 0 {
                Spacer().frame(width: CGFloat(result.level * 24))
            }
            
            ZStack {
                if result.hasChildren {
                    Button(action: onToggleExpand) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .rotationEffect(.degrees(result.isExpanded ? 90 : 0))
                            .foregroundColor(.secondaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 24, height: 24)
            
            Image(systemName: result.isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 24))
                .foregroundColor(result.isSelected ? .accentBlue : .secondaryText.opacity(0.8))
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(result.path.hasSuffix(".app") ? Color.accentBlue.opacity(0.15) : Color.gray.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: result.path.hasSuffix(".app") ? "app.dashed" : (result.hasChildren ? "folder.fill" : "doc.text.fill"))
                    .font(.system(size: 20))
                    .foregroundColor(result.path.hasSuffix(".app") ? .accentBlue : .primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text((result.path as NSString).lastPathComponent)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text(result.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0.05), radius: isHovering ? 5 : 2, x: 0, y: isHovering ? 3 : 1)
        .scaleEffect(isHovering ? 1.005 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture {
            onToggleSelection()
        }
    }
}

// MARK: - SwiftUI Preview
#Preview {
    ContentView()
}
