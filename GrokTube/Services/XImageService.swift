//
//  XImageService.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import SwiftUI

/// Service to fetch images from X.com (Twitter) using Grok API
class XImageService: ObservableObject {
    static let shared = XImageService()
    
    private let apiKey = "xai-I1UBCLc2IYDCMaJSY8V7MJ8nKsjx9gXNQj1ajO3yPGwvyQpPNMPxjPOjGeJCYVNMUJNiLIkzjhslHPgJ"
    private let baseURL = "https://api.x.ai/v1/chat/completions"
    
    // Cache for fetched images
    @Published var imageCache: [String: [XImage]] = [:]
    @Published var isLoading: [String: Bool] = [:]
    
    struct XImage: Identifiable, Codable {
        let id: String
        let url: String
        let description: String?
        let author: String?
        let tweetUrl: String?
        
        init(id: String = UUID().uuidString, url: String, description: String? = nil, author: String? = nil, tweetUrl: String? = nil) {
            self.id = id
            self.url = url
            self.description = description
            self.author = author
            self.tweetUrl = tweetUrl
        }
    }
    
    /// Fetch images for a London destination from X.com
    func fetchImages(for spotName: String, location: String = "London") async -> [XImage] {
        // Check cache first
        let cacheKey = "\(spotName)-\(location)"
        if let cached = imageCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        await MainActor.run {
            isLoading[cacheKey] = true
        }
        
        defer {
            Task { @MainActor in
                isLoading[cacheKey] = false
            }
        }
        
        // Use Grok to search for images on X
        let searchQuery = "\(spotName) \(location) park garden nature photo"
        
        let requestBody: [String: Any] = [
            "model": "grok-2-latest",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful assistant that finds beautiful photos of London parks and calm spots shared on X (Twitter).
                    When asked about a location, provide 3-5 image URLs from X posts showing that location.
                    Return ONLY a JSON array with objects containing: url (image URL), description (brief caption), author (X username).
                    Use real, publicly accessible image URLs from X/Twitter CDN (pbs.twimg.com).
                    If you cannot find real images, return representative placeholder URLs.
                    """
                ],
                [
                    "role": "user",
                    "content": "Find beautiful photos of \(spotName) in \(location) shared on X. Return as JSON array."
                ]
            ],
            "search": [
                "mode": "auto",
                "sources": [
                    ["type": "x"]
                ]
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: baseURL) else {
            return getPlaceholderImages(for: spotName)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return getPlaceholderImages(for: spotName)
            }
            
            print("📸 X Image API Response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Try to parse JSON from the response
                    let images = parseImagesFromResponse(content, spotName: spotName)
                    
                    await MainActor.run {
                        self.imageCache[cacheKey] = images
                    }
                    
                    return images
                }
            } else {
                // Log error response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorString)")
                }
            }
        } catch {
            print("❌ Failed to fetch X images: \(error)")
        }
        
        return getPlaceholderImages(for: spotName)
    }
    
    private func parseImagesFromResponse(_ content: String, spotName: String) -> [XImage] {
        // Try to extract JSON array from response
        var jsonString = content
        
        // Remove markdown code blocks if present
        if let start = jsonString.range(of: "```json") {
            jsonString = String(jsonString[start.upperBound...])
        } else if let start = jsonString.range(of: "```") {
            jsonString = String(jsonString[start.upperBound...])
        }
        if let end = jsonString.range(of: "```") {
            jsonString = String(jsonString[..<end.lowerBound])
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find JSON array
        if let startBracket = jsonString.firstIndex(of: "["),
           let endBracket = jsonString.lastIndex(of: "]") {
            jsonString = String(jsonString[startBracket...endBracket])
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            print("⚠️ Could not parse image JSON, using placeholders")
            return getPlaceholderImages(for: spotName)
        }
        
        var images: [XImage] = []
        
        for item in jsonArray {
            if let url = item["url"] as? String {
                let image = XImage(
                    url: url,
                    description: item["description"] as? String ?? item["caption"] as? String,
                    author: item["author"] as? String ?? item["username"] as? String,
                    tweetUrl: item["tweet_url"] as? String ?? item["tweetUrl"] as? String
                )
                images.append(image)
            }
        }
        
        return images.isEmpty ? getPlaceholderImages(for: spotName) : images
    }
    
    /// Get curated placeholder images for London spots
    private func getPlaceholderImages(for spotName: String) -> [XImage] {
        // High-quality Unsplash images of London parks (free to use)
        let londonParkImages: [String: [XImage]] = [
            "Kyoto Garden": [
                XImage(url: "https://images.unsplash.com/photo-1580502304784-8985b7eb7260?w=800", description: "Kyoto Garden waterfall", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?w=800", description: "Japanese garden in London", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1588714477688-cf28a50e94f7?w=800", description: "Peaceful pond", author: "unsplash")
            ],
            "Hampstead Heath": [
                XImage(url: "https://images.unsplash.com/photo-1534067783941-51c9c23ecefd?w=800", description: "Hampstead Heath views", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800", description: "Green meadow", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800", description: "Forest path", author: "unsplash")
            ],
            "Richmond Park": [
                XImage(url: "https://images.unsplash.com/photo-1474511320723-9a56873571b7?w=800", description: "Deer in Richmond Park", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=800", description: "Oak trees", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800", description: "Park landscape", author: "unsplash")
            ],
            "Kew Gardens": [
                XImage(url: "https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800", description: "Kew Gardens greenhouse", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800", description: "Botanical garden", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=800", description: "Flower gardens", author: "unsplash")
            ],
            "Hyde Park": [
                XImage(url: "https://images.unsplash.com/photo-1543832923-44667a44c804?w=800", description: "Hyde Park lake", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1508020963102-c6de10fa7e8b?w=800", description: "Park in autumn", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=800", description: "Serpentine", author: "unsplash")
            ],
            "Regent": [
                XImage(url: "https://images.unsplash.com/photo-1551009175-15bdf9dcb580?w=800", description: "Regent's Park roses", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=800", description: "Garden flowers", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800", description: "Park gardens", author: "unsplash")
            ],
            "Victoria Park": [
                XImage(url: "https://images.unsplash.com/photo-1508020963102-c6de10fa7e8b?w=800", description: "Victoria Park", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800", description: "Green spaces", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800", description: "Trees", author: "unsplash")
            ],
            "Greenwich": [
                XImage(url: "https://images.unsplash.com/photo-1486299267070-83823f5448dd?w=800", description: "Greenwich views", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800", description: "London skyline", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1529655683826-aba9b3e77383?w=800", description: "Park view", author: "unsplash")
            ],
            "British Museum": [
                XImage(url: "https://images.unsplash.com/photo-1569183091671-696402586b9c?w=800", description: "British Museum interior", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1575223970966-76ae61ee7838?w=800", description: "Museum architecture", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800", description: "Historic building", author: "unsplash")
            ],
            "St James": [
                XImage(url: "https://images.unsplash.com/photo-1529655683826-aba9b3e77383?w=800", description: "St James Park", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1543832923-44667a44c804?w=800", description: "Park lake", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1508020963102-c6de10fa7e8b?w=800", description: "Royal park", author: "unsplash")
            ],
            "Barbican": [
                XImage(url: "https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=800", description: "Barbican greenery", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=800", description: "Indoor garden", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800", description: "Conservatory", author: "unsplash")
            ],
            "default": [
                XImage(url: "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800", description: "London cityscape", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1529655683826-aba9b3e77383?w=800", description: "London park", author: "unsplash"),
                XImage(url: "https://images.unsplash.com/photo-1486299267070-83823f5448dd?w=800", description: "Thames view", author: "unsplash")
            ]
        ]
        
        // Try to match spot name
        for (key, images) in londonParkImages {
            if spotName.lowercased().contains(key.lowercased()) || key.lowercased().contains(spotName.lowercased()) {
                return images
            }
        }
        
        return londonParkImages["default"] ?? []
    }
}

// MARK: - Async Image View with X Attribution

struct XImageView: View {
    let imageURL: String
    let author: String?
    var showAttribution: Bool = true
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            if showAttribution, let author = author {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 8))
                                    Text("@\(author)")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                                .padding(6)
                            }
                        }
                } else if isLoading {
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [.green.opacity(0.6), .mint.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = URL(string: imageURL) else {
            isLoading = false
            loadFailed = true
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: imageURL) {
            self.image = cachedImage
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ImageCache.shared.set(uiImage, forKey: imageURL)
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.loadFailed = true
                }
            }
        } catch {
            print("❌ Failed to load image: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
        }
    }
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Image Carousel for Spot Detail

struct SpotImageCarousel: View {
    let spotName: String
    @StateObject private var imageService = XImageService.shared
    @State private var images: [XImageService.XImage] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    XImageView(imageURL: image.url, author: image.author)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottom) {
                if images.count > 1 {
                    // Custom page indicator
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                }
            }
            .overlay(alignment: .topTrailing) {
                // X logo attribution
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Photos")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(12)
            }
        }
        .overlay {
            if isLoading && images.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading photos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        isLoading = true
        let fetchedImages = await imageService.fetchImages(for: spotName)
        await MainActor.run {
            self.images = fetchedImages
            self.isLoading = false
        }
    }
}
