#!/usr/bin/env swift

import Foundation
import SwiftUI

// MARK: - Progress UI Test Application

struct ProgressUITestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

struct ContentView: View {
    @StateObject private var testManager = ProgressTestManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Knowledge Base Progress Test")
                .font(.title)
                .padding()

            ProgressTestView(manager: testManager)
                .frame(maxWidth: 500)

            HStack(spacing: 20) {
                Button("Start Test Processing") {
                    Task {
                        await testManager.simulateProcessing()
                    }
                }
                .disabled(testManager.isProcessing)

                Button("Start with Error") {
                    Task {
                        await testManager.simulateProcessingWithError()
                    }
                }
                .disabled(testManager.isProcessing)

                Button("Cancel") {
                    Task {
                        await testManager.cancelProcessing()
                    }
                }
                .disabled(!testManager.isProcessing)
            }
            .padding()

            Spacer()
        }
        .padding(20)
    }
}

struct ProgressTestView: View {
    @ObservedObject var manager: ProgressTestManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)

            // Progress Section - Only show when processing
            if manager.isProcessing {
                VStack(alignment: .leading, spacing: 12) {
                    // Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(
                                manager.currentStep.isEmpty ? "Processing..." : manager.currentStep
                            )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                            Spacer()

                            // Cancel Button
                            Button(action: {
                                Task {
                                    await manager.cancelProcessing()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Cancel")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            if manager.totalFiles > 0 {
                                Text("\(manager.processedFiles)/\(manager.totalFiles)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                            }
                        }

                        ProgressView(value: manager.processingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                            .animation(.easeInOut(duration: 0.3), value: manager.processingProgress)
                    }

                    // Current File Info
                    if !manager.currentFile.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text(manager.currentFile)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    // Status Message
                    if !manager.processingStatus.isEmpty {
                        HStack(spacing: 6) {
                            Image(
                                systemName: manager.hasError
                                    ? "exclamationmark.triangle" : "info.circle"
                            )
                            .font(.system(size: 11))
                            .foregroundColor(manager.hasError ? .red : .blue)

                            Text(manager.processingStatus)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(manager.hasError ? Color.red.opacity(0.05) : Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            manager.hasError ? Color.red.opacity(0.2) : Color.blue.opacity(0.2),
                            lineWidth: 1)
                )
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.3), value: manager.isProcessing)
            }

            // Mock Index Files Button
            Button(action: {
                Task {
                    await manager.simulateProcessing()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: manager.isProcessing ? "stop.circle" : "folder.badge.plus")
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.isProcessing ? "Processing..." : "Index Files")
                            .font(.system(size: 13, weight: .medium))

                        Text(
                            manager.isProcessing
                                ? "Please wait..." : "Process documents and create embeddings"
                        )
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(manager.isProcessing)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Progress Test Manager

@MainActor
class ProgressTestManager: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentFile = ""
    @Published var totalFiles = 0
    @Published var processedFiles = 0
    @Published var currentStep = ""
    @Published var processingStatus = ""
    @Published var hasError = false

    private var processingTask: Task<Void, Never>?

    private let testFiles = [
        "README.md",
        "Installation Guide.txt",
        "Configuration.md",
        "API Documentation.md",
        "User Manual.pdf",
        "Troubleshooting.md",
        "FAQ.txt",
        "Release Notes.md",
    ]

    func simulateProcessing() async {
        guard !isProcessing else { return }

        isProcessing = true
        hasError = false
        processingProgress = 0.0
        currentFile = ""
        totalFiles = testFiles.count
        processedFiles = 0
        currentStep = "Preparing..."
        processingStatus = ""

        processingTask = Task {
            do {
                // Step 1: Configuration
                await updateStep("Saving configuration...", progress: 0.1)
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

                // Step 2: Scanning
                await updateStep("Scanning files...", progress: 0.2)
                try await Task.sleep(nanoseconds: 800_000_000)  // 0.8s

                // Step 3: Processing files
                await updateStep("Processing documents...", progress: 0.3)

                for (index, fileName) in testFiles.enumerated() {
                    try Task.checkCancellation()

                    currentFile = fileName
                    processedFiles = index
                    processingStatus = "Processing: \(fileName)"

                    // Simulate file processing time
                    let processingTime = UInt64.random(in: 300_000_000...1_000_000_000)  // 0.3-1.0s
                    try await Task.sleep(nanoseconds: processingTime)

                    // Update progress
                    let fileProgress = 0.4 * Double(index + 1) / Double(testFiles.count)
                    processingProgress = 0.3 + fileProgress
                }

                processedFiles = testFiles.count
                currentFile = ""

                // Step 4: Generating embeddings
                await updateStep("Generating embeddings...", progress: 0.8)

                for (index, fileName) in testFiles.enumerated() {
                    try Task.checkCancellation()

                    currentFile = fileName
                    processingStatus = "Creating vectors for: \(fileName)"

                    try await Task.sleep(nanoseconds: 400_000_000)  // 0.4s

                    let embeddingProgress = 0.15 * Double(index + 1) / Double(testFiles.count)
                    processingProgress = 0.8 + embeddingProgress
                }

                currentFile = ""

                // Step 5: Saving to database
                await updateStep("Saving to vector database...", progress: 0.96)
                try await Task.sleep(nanoseconds: 600_000_000)  // 0.6s

                // Step 6: Completion
                await updateStep("Completed successfully!", progress: 1.0)
                processingStatus =
                    "Processed \(testFiles.count) files, created \(testFiles.count * 3) vectors"

                // Show completion for 2 seconds
                try await Task.sleep(nanoseconds: 2_000_000_000)

                await resetProgress()

            } catch is CancellationError {
                await updateStep("Cancelled", progress: 0.0)
                processingStatus = "Processing cancelled by user"
                hasError = false

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await resetProgress()

            } catch {
                await handleError("Processing failed: \(error.localizedDescription)")
            }
        }
    }

    func simulateProcessingWithError() async {
        guard !isProcessing else { return }

        isProcessing = true
        hasError = false
        processingProgress = 0.0
        currentFile = ""
        totalFiles = testFiles.count
        processedFiles = 0
        currentStep = "Preparing..."
        processingStatus = ""

        processingTask = Task {
            do {
                // Start normal processing
                await updateStep("Scanning files...", progress: 0.2)
                try await Task.sleep(nanoseconds: 500_000_000)

                await updateStep("Processing documents...", progress: 0.3)

                // Process a few files successfully
                for index in 0..<3 {
                    try Task.checkCancellation()

                    let fileName = testFiles[index]
                    currentFile = fileName
                    processedFiles = index
                    processingStatus = "Processing: \(fileName)"

                    try await Task.sleep(nanoseconds: 600_000_000)

                    let fileProgress = 0.2 * Double(index + 1) / Double(testFiles.count)
                    processingProgress = 0.3 + fileProgress
                }

                // Simulate error on 4th file
                await handleError("Failed to read file: \(testFiles[3]) - Permission denied")

            } catch is CancellationError {
                await updateStep("Cancelled", progress: 0.0)
                processingStatus = "Processing cancelled by user"
                hasError = false

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await resetProgress()
            }
        }
    }

    func cancelProcessing() async {
        processingTask?.cancel()

        currentStep = "Cancelling..."
        processingStatus = "Cancelling processing..."
    }

    private func updateStep(_ step: String, progress: Double) async {
        currentStep = step
        processingProgress = progress
    }

    private func handleError(_ message: String) async {
        hasError = true
        currentStep = "Error occurred"
        processingStatus = message
        currentFile = ""

        // Show error for 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        await resetProgress()
    }

    private func resetProgress() async {
        isProcessing = false
        processingProgress = 0.0
        currentStep = ""
        currentFile = ""
        totalFiles = 0
        processedFiles = 0
        processingStatus = ""
        hasError = false
    }
}

// MARK: - Main Entry Point

// For command line execution
if CommandLine.arguments.contains("--run") {
    print("🧪 Testing Progress UI...")
    print("This test simulates the knowledge base processing progress bar.")
    print("Run this file in Xcode or as a SwiftUI app to see the visual progress bar.")

    let testManager = ProgressTestManager()

    Task {
        print("\n📊 Starting simulated processing...")
        await testManager.simulateProcessing()
        print("✅ Simulation completed!")

        print("\n❌ Testing error scenario...")
        await testManager.simulateProcessingWithError()
        print("✅ Error simulation completed!")

        exit(0)
    }

    RunLoop.main.run()
} else {
    print("Progress UI Test - Usage:")
    print("  swift test_progress_ui.swift --run    # Run command line test")
    print("  # Or open in Xcode to see visual progress bar")
}
