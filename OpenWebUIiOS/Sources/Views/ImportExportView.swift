import SwiftUI

struct ImportExportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var exportFormat = ExportFormat.json
    @State private var showingImportPicker = false
    @State private var showingExportOptions = false
    @State private var selectedConversations: [UUID] = []
    @State private var exportProgress: Double = 0
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case markdown = "Markdown"
        case pdf = "PDF"
        case txt = "Text"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Import")) {
                    Button(action: {
                        showingImportPicker = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.accentColor)
                            Text("Import Conversations")
                        }
                    }
                    .disabled(isImporting || isExporting)
                    
                    if isImporting {
                        ProgressView(value: exportProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Export")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                            Text("Export Conversations")
                        }
                    }
                    .disabled(isImporting || isExporting)
                    
                    if isExporting {
                        VStack {
                            ProgressView(value: exportProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text("Exporting conversations...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Options"), footer: exportFormatFooter) {
                    Toggle("Include System Messages", isOn: .constant(true))
                    Toggle("Include Metadata", isOn: .constant(true))
                    Toggle("Compress Output", isOn: .constant(false))
                }
            }
            .navigationTitle("Import/Export")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingImportPicker) {
                // Mock file picker for importing
                // In a real implementation, this would use a document picker
                VStack(spacing: 20) {
                    Text("Select Files to Import")
                        .font(.headline)
                    
                    Button("Simulate File Selection") {
                        // Simulate import process
                        simulateImport()
                        showingImportPicker = false
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Cancel") {
                        showingImportPicker = false
                    }
                    .padding()
                }
                .padding()
            }
            .actionSheet(isPresented: $showingExportOptions) {
                ActionSheet(
                    title: Text("Export Options"),
                    message: Text("Choose which conversations to export"),
                    buttons: [
                        .default(Text("All Conversations")) {
                            simulateExport(mode: "all")
                        },
                        .default(Text("Only Selected Conversations")) {
                            simulateExport(mode: "selected")
                        },
                        .default(Text("Current Conversation")) {
                            simulateExport(mode: "current")
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private var exportFormatFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Format Details:")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("• JSON: Complete data with metadata")
                .font(.caption)
            
            Text("• Markdown: Formatted conversations readable in any markdown viewer")
                .font(.caption)
            
            Text("• PDF: Printable document format")
                .font(.caption)
            
            Text("• Text: Plain text format")
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    // Simulates the import process
    private func simulateImport() {
        isImporting = true
        exportProgress = 0
        
        // Simulate progress with a timer
        let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
        var progressCount = 0
        
        let progressSubscription = timer.sink { _ in
            progressCount += 1
            exportProgress = min(Double(progressCount) * 0.1, 1.0)
            
            if exportProgress >= 1.0 {
                isImporting = false
                timer.upstream.connect().cancel()
                
                // Show success message
                alertTitle = "Import Complete"
                alertMessage = "Successfully imported 3 conversations."
                showingAlert = true
            }
        }
        
        // Store subscription to prevent it from being deallocated
        _ = progressSubscription
    }
    
    // Simulates the export process
    private func simulateExport(mode: String) {
        isExporting = true
        exportProgress = 0
        
        // Simulate progress with a timer
        let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
        var progressCount = 0
        
        let progressSubscription = timer.sink { _ in
            progressCount += 1
            exportProgress = min(Double(progressCount) * 0.1, 1.0)
            
            if exportProgress >= 1.0 {
                isExporting = false
                timer.upstream.connect().cancel()
                
                // Show success message
                let count = mode == "all" ? "10" : (mode == "selected" ? "5" : "1")
                alertTitle = "Export Complete"
                alertMessage = "Successfully exported \(count) conversations as \(exportFormat.rawValue)."
                showingAlert = true
            }
        }
        
        // Store subscription to prevent it from being deallocated
        _ = progressSubscription
    }
}

struct ImportExportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportExportView()
    }
}