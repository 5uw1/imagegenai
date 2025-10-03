//
//  ContentView.swift
//  imagegenai
//
//  Created by Suwijak Thanawiboon on 3/10/2568 BE.
//

import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = ImageGeneratorViewModel()
    @State private var showingSettings = false
    @State private var hasAPIKey: Bool = APIKeyProvider.openAIKey() != nil
    @State private var selectedImage: GeneratedImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Describe the image you want...", text: $viewModel.prompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .submitLabel(.go)
                        .onSubmit {
                            viewModel.generate(size: "1024x1024")
                        }

                    Button {
                        viewModel.generate(size: "1024x1024")
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Generate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.isLoading ||
                        viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !hasAPIKey
                    )
                }
                .padding(.horizontal)

                // Inline prompt when API key is missing
                if !hasAPIKey {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.yellow)
                        Text("Add your OpenAI API key in Settings to generate images.")
                        Button("Open Settings") {
                            showingSettings = true
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                }

                if viewModel.images.isEmpty {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No images yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.images) { item in
                            Button {
                                selectedImage = item
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    ThumbnailView(url: item.fileURL)
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                        .clipped()

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.prompt)
                                            .font(.headline)
                                            .lineLimit(2)
                                        Text(item.date, formatter: DateFormatter.short)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: viewModel.delete(at:))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("AI Image Generator")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.images.isEmpty {
                        EditButton()
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .onAppear {
            viewModel.loadImages()
            hasAPIKey = APIKeyProvider.openAIKey() != nil
        }
        .onChange(of: showingSettings) {
            // Refresh key presence after Settings is dismissed
            if !showingSettings {
                hasAPIKey = APIKeyProvider.openAIKey() != nil
            }
        }
        .alert("Error", isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { newValue in
            if !newValue { viewModel.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Full‑screen modal for full image
        .fullScreenCover(item: $selectedImage) { item in
            FullImageView(url: item.fileURL)
        }
        // Settings modal
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

struct ThumbnailView: View {
    let url: URL
    var body: some View {
        if let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension DateFormatter {
    static let short: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}

#Preview {
    ContentView()
}
