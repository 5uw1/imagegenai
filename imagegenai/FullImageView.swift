// FullImageView.swift
import SwiftUI
import UIKit

struct FullImageView: View {
    let url: URL
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let image = uiImage {
                ZoomableImage(uiImage: image)
                    .background(Color.black)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading image…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .task {
            if uiImage == nil {
                uiImage = UIImage(contentsOfFile: url.path)
            }
        }
        .navigationTitle("Full Size")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if uiImage != nil {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
            }
        }
    }
}

// UIScrollView-backed zoomable image that sets the correct initial zoom
private struct ZoomableImage: UIViewRepresentable {
    let uiImage: UIImage

    func makeCoordinator() -> Coordinator { Coordinator(image: uiImage) }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        // Pin imageView to the content layout guide so UIScrollView manages content size.
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Keep the image centered when it’s smaller than the scroll view.
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        // Double‑tap to zoom
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Ensure we set the zoom AFTER the scroll view has a valid size.
        context.coordinator.updateZoomScalesIfNeeded()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        let imageSize: CGSize
        private var didSetInitialZoom = false

        init(image: UIImage) {
            self.imageSize = image.size
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        func updateZoomScalesIfNeeded() {
            guard let scrollView, let imageView else { return }

            // Wait for valid bounds.
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds.height > 0 else {
                DispatchQueue.main.async { [weak self] in self?.updateZoomScalesIfNeeded() }
                return
            }

            // Compute min zoom to fit the image.
            let xScale = bounds.width / imageSize.width
            let yScale = bounds.height / imageSize.height
            let minScale = max(min(xScale, yScale), 0.01)
            let maxScale = max(4.0, minScale * 6.0)

            if scrollView.minimumZoomScale != minScale || scrollView.maximumZoomScale != maxScale {
                scrollView.minimumZoomScale = minScale
                scrollView.maximumZoomScale = maxScale
            }

            if !didSetInitialZoom {
                didSetInitialZoom = true
                scrollView.zoomScale = minScale
                centerImage()
            } else {
                centerImage()
            }

            // Natural content size; UIScrollView handles scaling.
            imageView.frame = CGRect(origin: .zero, size: imageSize)
            scrollView.contentSize = imageSize
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            // Center via contentInset so the image stays centered while zooming.
            let bounds = scrollView.bounds.size
            let scaledWidth = imageView.frame.size.width * scrollView.zoomScale
            let scaledHeight = imageView.frame.size.height * scrollView.zoomScale
            let insetX = max(0, (bounds.width - scaledWidth) / 2)
            let insetY = max(0, (bounds.height - scaledHeight) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let newScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2)
                let point = gesture.location(in: imageView)
                let size = scrollView.bounds.size
                let w = size.width / newScale
                let h = size.height / newScale
                let rect = CGRect(x: point.x - w/2, y: point.y - h/2, width: w, height: h)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
