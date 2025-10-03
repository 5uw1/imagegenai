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
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading image…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .task {
            if uiImage == nil {
                uiImage = UIImage(contentsOfFile: url.path)
            }
        }
        .navigationTitle("Full Size")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(uiImage == nil)
                .accessibilityLabel("Share")
            }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let uiImage: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.bouncesZoom = true
        scrollView.maximumZoomScale = 6.0

        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }

        imageView.image = uiImage
        imageView.frame = CGRect(origin: .zero, size: uiImage.size)
        scrollView.contentSize = uiImage.size

        // Compute min scale to fit
        let minScale = min(
            scrollView.bounds.size.width / uiImage.size.width,
            scrollView.bounds.size.height / uiImage.size.height
        )

        scrollView.minimumZoomScale = max(minScale, 0.01)
        if scrollView.zoomScale < scrollView.minimumZoomScale || scrollView.zoomScale == 1.0 {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
        Coordinator.centerImage(in: scrollView, imageView: imageView)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let imageView = imageView {
                Self.centerImage(in: scrollView, imageView: imageView)
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            let newScale: CGFloat
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                newScale = scrollView.minimumZoomScale
                scrollView.setZoomScale(newScale, animated: true)
            } else {
                newScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2)
                let pointInView = gesture.location(in: imageView)
                let size = scrollView.bounds.size
                let w = size.width / newScale
                let h = size.height / newScale
                let x = pointInView.x - (w / 2.0)
                let y = pointInView.y - (h / 2.0)
                let zoomRect = CGRect(x: x, y: y, width: w, height: h)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        static func centerImage(in scrollView: UIScrollView, imageView: UIImageView) {
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }
    }
}
