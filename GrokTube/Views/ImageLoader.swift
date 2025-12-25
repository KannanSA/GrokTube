//
//  ImageLoader.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Async image loader with caching for park images
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    ImageCache.shared.set(downloadedImage, forKey: url.absoluteString)
                    await MainActor.run {
                        self.image = downloadedImage
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

/// Simple image cache
class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Park image view with placeholder
struct ParkImageView: View {
    let spot: CalmSpot
    let size: CGSize
    
    var body: some View {
        Group {
            if let urlString = spot.imageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } placeholder: {
                    ParkImagePlaceholder(spot: spot, size: size)
                }
            } else {
                ParkImagePlaceholder(spot: spot, size: size)
            }
        }
    }
}

/// Placeholder with gradient and icon
struct ParkImagePlaceholder: View {
    let spot: CalmSpot
    let size: CGSize
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: spot.systemImage)
                .font(.system(size: min(size.width, size.height) * 0.4))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: size.width, height: size.height)
    }
    
    private var gradientColors: [Color] {
        // Different gradients based on tags
        if spot.tags.contains("Japanese") || spot.tags.contains("Peaceful") {
            return [.green.opacity(0.8), .mint.opacity(0.6)]
        } else if spot.tags.contains("Historic") {
            return [.brown.opacity(0.7), .orange.opacity(0.5)]
        } else if spot.tags.contains("Wildlife") || spot.tags.contains("Nature") {
            return [.green.opacity(0.7), .teal.opacity(0.5)]
        } else if spot.tags.contains("Indoor") {
            return [.purple.opacity(0.6), .pink.opacity(0.4)]
        } else {
            return [.green.opacity(0.7), .blue.opacity(0.5)]
        }
    }
}

/// Shimmer loading effect
struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.2)
            ],
            startPoint: .init(x: phase - 0.5, y: 0),
            endPoint: .init(x: phase + 0.5, y: 0)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

#Preview {
    VStack {
        ParkImageView(
            spot: CalmSpot.allSpots[0],
            size: CGSize(width: 200, height: 150)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        ParkImagePlaceholder(
            spot: CalmSpot.allSpots[1],
            size: CGSize(width: 200, height: 150)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
