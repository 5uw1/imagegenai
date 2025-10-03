// FullImageView.swift
import SwiftUI
import UIKit

struct FullImageView: View {
    let url: URL
    @State private var uiImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = uiImage {
                ZoomableImage(uiImage: image)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible.toggle()
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading image…")
                        .foregroundStyle(.secondary)
                }
            }

            if controlsVisible {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")

                    Spacer()

                    if uiImage != nil {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Share")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .ignoresSafeArea(edges: .top)
            }
        }
        .task {
            if uiImage == nil {
                uiImage = UIImage(contentsOfFile: url.path)
            }
        }
        .statusBarHidden(!controlsVisible)
        .preferredColorScheme(.dark)
    }
}

// UIScrollView-backed zoomable image with proper initial zoom-to-fit and centering.
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
        scrollView.contentInsetAdjustmentBehavior = .never

        // Use a plain frame-based image view for predictable zoom behavior.
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleToFill
        imageView.frame = CGRect(origin: .zero, size: uiImage.size)
        scrollView.addSubview(imageView)

        scrollView.contentSize = uiImage.size

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
            scrollView.layoutIfNeeded()
            let inset = scrollView.adjustedContentInset
            let available = CGSize(
                width: max(0, scrollView.bounds.width - inset.left - inset.right),
                height: max(0, scrollView.bounds.height - inset.top - inset.bottom)
            )
            guard available.width > 0, available.height > 0 else {
                DispatchQueue.main.async { [weak self] in self?.updateZoomScalesIfNeeded() }
                return
            }

            // Compute min zoom to fit the image within the visible area.
            let xScale = available.width / imageSize.width
            let yScale = available.height / imageSize.height
            let minScale = max(min(xScale, yScale), 0.01)

            // Allow generous zoom-in.
            let maxScale = max(8.0, minScale * 10.0)

            if scrollView.minimumZoomScale != minScale || scrollView.maximumZoomScale != maxScale {
                scrollView.minimumZoomScale = minScale
                scrollView.maximumZoomScale = maxScale
            }

            // Ensure base geometry is correct for zooming.
            imageView.frame = CGRect(origin: .zero, size: imageSize)
            scrollView.contentSize = imageSize

            if !didSetInitialZoom {
                didSetInitialZoom = true
                scrollView.zoomScale = minScale   // Fit-to-screen on first display.
                centerImage()
            } else {
                centerImage()
            }
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let bounds = scrollView.bounds.size
            let inset = scrollView.adjustedContentInset
            let visibleWidth = bounds.width - inset.left - inset.right
            let visibleHeight = bounds.height - inset.top - inset.bottom
            let scaledWidth = imageView.bounds.width * scrollView.zoomScale
            let scaledHeight = imageView.bounds.height * scrollView.zoomScale
            let insetX = max(0, (visibleWidth - scaledWidth) / 2)
            let insetY = max(0, (visibleHeight - scaledHeight) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let newScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
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
