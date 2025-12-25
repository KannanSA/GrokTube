//
//  XImageService.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import SwiftUI
import Combine

/// Service to fetch images and tweets from X.com (Twitter) using Grok API
class XImageService: ObservableObject {
    static let shared = XImageService()
    
    private let apiKey = "xai-I1UBCLc2IYDCMaJSY8V7MJ8nKsjx9gXNQj1ajO3yPGwvyQpPNMPxjPOjGeJCYVNMUJNiLIkzjhslHPgJ"
    private let baseURL = "https://api.x.ai/v1/chat/completions"
    
    // Cache for fetched content
    @Published var imageCache: [String: [XImage]] = [:]
    @Published var tweetCache: [String: [XTweet]] = [:]
    @Published var isLoading: [String: Bool] = [:]
    @Published var lastRefresh: [String: Date] = [:]
    
    // Refresh interval (5 minutes)
    private let refreshInterval: TimeInterval = 300
    
    struct XImage: Identifiable, Codable {
        let id: String
        let url: String
        let description: String?
        let author: String?
        let tweetUrl: String?
        let timestamp: Date?
        
        init(id: String = UUID().uuidString, url: String, description: String? = nil, author: String? = nil, tweetUrl: String? = nil, timestamp: Date? = nil) {
            self.id = id
            self.url = url
            self.description = description
            self.author = author
            self.tweetUrl = tweetUrl
            self.timestamp = timestamp ?? Date()
        }
    }
    
    struct XTweet: Identifiable, Codable {
        let id: String
        let text: String
        let author: String
        let authorHandle: String
        let tweetUrl: String?
        let imageUrls: [String]
        let timestamp: Date?
        let likes: Int?
        let retweets: Int?
        
        init(id: String = UUID().uuidString, text: String, author: String, authorHandle: String, tweetUrl: String? = nil, imageUrls: [String] = [], timestamp: Date? = nil, likes: Int? = nil, retweets: Int? = nil) {
            self.id = id
            self.text = text
            self.author = author
            self.authorHandle = authorHandle
            self.tweetUrl = tweetUrl
            self.imageUrls = imageUrls
            self.timestamp = timestamp ?? Date()
            self.likes = likes
            self.retweets = retweets
        }
    }
    
    /// Fetch live feed (images and tweets) for a London destination from X.com
    func fetchLiveFeed(for spotName: String, location: String = "London", forceRefresh: Bool = false) async -> ([XImage], [XTweet]) {
        let cacheKey = "\(spotName)-\(location)"
        
        // Check if we need to refresh
        if !forceRefresh,
           let lastRefreshTime = lastRefresh[cacheKey],
           Date().timeIntervalSince(lastRefreshTime) < refreshInterval,
           let cachedImages = imageCache[cacheKey],
           let cachedTweets = tweetCache[cacheKey],
           !cachedImages.isEmpty || !cachedTweets.isEmpty {
            return (cachedImages, cachedTweets)
        }
        
        await MainActor.run {
            isLoading[cacheKey] = true
        }
        
        defer {
            Task { @MainActor in
                isLoading[cacheKey] = false
                lastRefresh[cacheKey] = Date()
            }
        }
        
        // Fetch both images and tweets
        async let imagesTask = fetchImagesFromX(for: spotName, location: location)
        async let tweetsTask = fetchTweetsFromX(for: spotName, location: location)
        
        let (images, tweets) = await (imagesTask, tweetsTask)
        
        await MainActor.run {
            self.imageCache[cacheKey] = images
            self.tweetCache[cacheKey] = tweets
        }
        
        return (images, tweets)
    }
    
    /// Fetch images for a London destination from X.com
    func fetchImages(for spotName: String, location: String = "London") async -> [XImage] {
        let cacheKey = "\(spotName)-\(location)"
        if let cached = imageCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        let images = await fetchImagesFromX(for: spotName, location: location)
        
        await MainActor.run {
            self.imageCache[cacheKey] = images
        }
        
        return images
    }
    
    private func fetchImagesFromX(for spotName: String, location: String) async -> [XImage] {
        await MainActor.run {
            isLoading["\(spotName)-\(location)"] = true
        }
        
        defer {
            Task { @MainActor in
                isLoading["\(spotName)-\(location)"] = false
            }
        }
        
        let requestBody: [String: Any] = [
            "model": "grok-2-latest",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful assistant that finds beautiful, SAFE FOR WORK photos of London parks and calm spots shared on X (Twitter).
                    
                    STRICT CONTENT GUIDELINES:
                    - ONLY include family-friendly, safe-for-work content
                    - Focus on nature, landscapes, architecture, gardens, and peaceful scenes
                    - NO controversial, political, violent, or adult content
                    - NO images with inappropriate text or gestures
                    - Prefer verified accounts, tourism accounts, and photography accounts
                    
                    When asked about a location, search X for recent posts with photos and return 5-8 image URLs.
                    Return ONLY a valid JSON array with objects containing:
                    - url: direct image URL (pbs.twimg.com format preferred)
                    - description: brief SFW caption (max 100 chars)
                    - author: X username without @
                    - tweet_url: link to original tweet
                    - timestamp: ISO 8601 date string
                    
                    If you cannot find suitable real images, return an empty array [].
                    """
                ],
                [
                    "role": "user",
                    "content": "Find recent beautiful, safe-for-work photos of \(spotName) in \(location) shared on X in the last 7 days. Return as JSON array only, no other text."
                ]
            ],
            "search": [
                "mode": "on",
                "return_citations": true,
                "sources": [
                    ["type": "x", "x_handles": [], "safe_search": true]
                ]
            ],
            "temperature": 0.3
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
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ X Image API Error")
                return getPlaceholderImages(for: spotName)
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                let images = parseImagesFromResponse(content, spotName: spotName)
                return images.isEmpty ? getPlaceholderImages(for: spotName) : images
            }
        } catch {
            print("❌ Failed to fetch X images: \(error)")
        }
        
        return getPlaceholderImages(for: spotName)
    }
    
    private func fetchTweetsFromX(for spotName: String, location: String) async -> [XTweet] {
        let requestBody: [String: Any] = [
            "model": "grok-2-latest",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful assistant that finds recent, SAFE FOR WORK tweets about London parks and calm spots.
                    
                    STRICT CONTENT GUIDELINES:
                    - ONLY include family-friendly, safe-for-work content
                    - Focus on visitor experiences, tips, nature observations, and peaceful moments
                    - NO controversial, political, argumentative, or adult content
                    - NO tweets with profanity or inappropriate language
                    - Prefer positive, informative, and inspiring tweets
                    - Include tweets with photos when available
                    
                    Return ONLY a valid JSON array with objects containing:
                    - text: tweet content (cleaned, max 280 chars)
                    - author: display name
                    - author_handle: X username without @
                    - tweet_url: link to original tweet
                    - image_urls: array of image URLs if any
                    - timestamp: ISO 8601 date string
                    - likes: number (estimate if unknown)
                    - retweets: number (estimate if unknown)
                    
                    Return 5-10 recent tweets. If you cannot find suitable content, return an empty array [].
                    """
                ],
                [
                    "role": "user",
                    "content": "Find recent safe-for-work tweets about \(spotName) in \(location) from the last 7 days. Include visitor photos, tips, and experiences. Return as JSON array only."
                ]
            ],
            "search": [
                "mode": "on",
                "return_citations": true,
                "sources": [
                    ["type": "x", "x_handles": [], "safe_search": true]
                ]
            ],
            "temperature": 0.3
        ]
        
        guard let url = URL(string: baseURL) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ X Tweets API Error")
                return []
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                return parseTweetsFromResponse(content)
            }
        } catch {
            print("❌ Failed to fetch X tweets: \(error)")
        }
        
        return []
    }
    
    private func parseTweetsFromResponse(_ content: String) -> [XTweet] {
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
        
        // Find JSON array
        if let startBracket = jsonString.firstIndex(of: "["),
           let endBracket = jsonString.lastIndex(of: "]") {
            jsonString = String(jsonString[startBracket...endBracket])
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            print("⚠️ Could not parse tweets JSON")
            return []
        }
        
        var tweets: [XTweet] = []
        
        for item in jsonArray {
            guard let text = item["text"] as? String,
                  let author = item["author"] as? String,
                  let authorHandle = item["author_handle"] as? String else {
                continue
            }
            
            // Additional SFW filter - skip tweets with common inappropriate words
            let lowercasedText = text.lowercased()
            let inappropriateWords = ["nsfw", "adult", "xxx", "nude", "porn", "sex", "drug", "weed", "drunk"]
            if inappropriateWords.contains(where: { lowercasedText.contains($0) }) {
                continue
            }
            
            let imageUrls = item["image_urls"] as? [String] ?? []
            
            let tweet = XTweet(
                text: text,
                author: author,
                authorHandle: authorHandle,
                tweetUrl: item["tweet_url"] as? String,
                imageUrls: imageUrls,
                timestamp: parseTimestamp(item["timestamp"]),
                likes: item["likes"] as? Int,
                retweets: item["retweets"] as? Int
            )
            tweets.append(tweet)
        }
        
        return tweets
    }
    
    private func parseTimestamp(_ value: Any?) -> Date? {
        guard let timestampString = value as? String else { return nil }
        
        let formatters = [
            ISO8601DateFormatter(),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: timestampString) {
                return date
            }
        }
        
        // Try custom format
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = customFormatter.date(from: timestampString) {
            return date
        }
        
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return customFormatter.date(from: timestampString)
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
// Note: Using ImageCache from ImageLoader.swift

// MARK: - Live Feed View for Spot Detail

struct SpotLiveFeedView: View {
    let spotName: String
    @StateObject private var imageService = XImageService.shared
    @State private var images: [XImageService.XImage] = []
    @State private var tweets: [XImageService.XTweet] = []
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab selector
            Picker("Feed Type", selection: $selectedTab) {
                Label("Photos", systemImage: "photo.stack.fill").tag(0)
                Label("Posts", systemImage: "text.bubble.fill").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == 0 {
                // Photos tab
                SpotImageCarousel(spotName: spotName, images: images, isLoading: isLoading)
            } else {
                // Tweets tab
                SpotTweetsFeed(tweets: tweets, isLoading: isLoading)
            }
            
            // Refresh button
            Button(action: {
                Task { await refreshFeed() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Refresh from X")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .disabled(isLoading)
        }
        .task {
            await loadFeed()
        }
    }
    
    private func loadFeed() async {
        isLoading = true
        let (fetchedImages, fetchedTweets) = await imageService.fetchLiveFeed(for: spotName)
        await MainActor.run {
            self.images = fetchedImages
            self.tweets = fetchedTweets
            self.isLoading = false
        }
    }
    
    private func refreshFeed() async {
        isLoading = true
        let (fetchedImages, fetchedTweets) = await imageService.fetchLiveFeed(for: spotName, forceRefresh: true)
        await MainActor.run {
            self.images = fetchedImages
            self.tweets = fetchedTweets
            self.isLoading = false
        }
    }
}

// MARK: - Image Carousel for Spot Detail

struct SpotImageCarousel: View {
    let spotName: String
    var images: [XImageService.XImage]
    var isLoading: Bool
    @State private var currentIndex = 0
    
    // For standalone use
    init(spotName: String) {
        self.spotName = spotName
        self.images = []
        self.isLoading = true
    }
    
    // For use within SpotLiveFeedView
    init(spotName: String, images: [XImageService.XImage], isLoading: Bool) {
        self.spotName = spotName
        self.images = images
        self.isLoading = isLoading
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if images.isEmpty && !isLoading {
                // No images placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No recent photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
            } else {
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
                        Text("𝕏")
                            .font(.system(size: 12, weight: .bold))
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
                .overlay(alignment: .bottomLeading) {
                    // Caption
                    if let description = images[safe: currentIndex]?.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                            .lineLimit(2)
                    }
                }
            }
        }
        .overlay {
            if isLoading && images.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading photos from X...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
            }
        }
    }
}

// MARK: - Tweets Feed View

struct SpotTweetsFeed: View {
    let tweets: [XImageService.XTweet]
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading && tweets.isEmpty {
                // Loading state
                ForEach(0..<3, id: \.self) { _ in
                    TweetCardPlaceholder()
                }
            } else if tweets.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No recent posts found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Check back later for updates")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tweets) { tweet in
                            TweetCard(tweet: tweet)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 300)
            }
        }
    }
}

// MARK: - Tweet Card

struct TweetCard: View {
    let tweet: XImageService.XTweet
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack(spacing: 10) {
                // Avatar placeholder
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(tweet.author.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tweet.author)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text("@\(tweet.authorHandle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // X logo
                Text("𝕏")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
            }
            
            // Tweet text
            Text(tweet.text)
                .font(.body)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Images (if any)
            if !tweet.imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tweet.imageUrls.prefix(4), id: \.self) { url in
                            XImageView(imageURL: url, author: nil, showAttribution: false)
                                .frame(width: 120, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            // Footer
            HStack(spacing: 16) {
                // Timestamp
                if let timestamp = tweet.timestamp {
                    Text(timeAgoString(from: timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Engagement
                if let likes = tweet.likes {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                        Text("\(formatCount(likes))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let retweets = tweet.retweets {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption)
                        Text("\(formatCount(retweets))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Open in X button
                if let urlString = tweet.tweetUrl, let url = URL(string: urlString) {
                    Button(action: { openURL(url) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Tweet Card Placeholder

struct TweetCardPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 10)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Safe Array Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
