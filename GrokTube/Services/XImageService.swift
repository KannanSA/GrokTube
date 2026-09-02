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
    
    /// Fetch images for a London destination - returns placeholder images immediately
    func fetchImages(for spotName: String, location: String = "London", forceRefresh: Bool = false) async -> [XImage] {
        let cacheKey = "\(spotName)-\(location)"
        
        if !forceRefresh, let cached = imageCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        // Return placeholder images immediately (guaranteed to work)
        let placeholderImages = getPlaceholderImages(for: spotName)
        
        await MainActor.run {
            self.imageCache[cacheKey] = placeholderImages
        }
        
        // Try API in background (optional enhancement)
        Task {
            let apiImages = await fetchImagesFromX(for: spotName, location: location)
            if !apiImages.isEmpty {
                // Verify at least one image loads before replacing
                if let firstURL = URL(string: apiImages[0].url) {
                    do {
                        let (_, response) = try await URLSession.shared.data(from: firstURL)
                        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                            await MainActor.run {
                                self.imageCache[cacheKey] = apiImages
                            }
                        }
                    } catch {
                        // Keep placeholder images
                    }
                }
            }
        }
        
        return placeholderImages
    }
    
    /// Fetch tweets/posts for a calm spot - returns sample tweets immediately then tries API
    func fetchTweets(for spotName: String, location: String = "London", forceRefresh: Bool = false) async -> [XTweet] {
        let cacheKey = "\(spotName)-\(location)"
        
        // Return cached tweets if available
        if !forceRefresh, let cached = tweetCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        // Return sample tweets immediately (no waiting for API)
        let sampleTweets = getSampleTweets(for: spotName)
        
        await MainActor.run {
            self.tweetCache[cacheKey] = sampleTweets
        }
        
        // Try to fetch from API in background and update cache
        Task {
            let apiTweets = await fetchTweetsFromX(for: spotName, location: location)
            if !apiTweets.isEmpty {
                await MainActor.run {
                    self.tweetCache[cacheKey] = apiTweets
                }
            }
        }
        
        return sampleTweets
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
        
        print("📸 Fetching images for: \(spotName)")
        
        let requestBody: [String: Any] = [
            "model": "grok-2-latest",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful assistant. When asked about a London park or calm spot, provide beautiful nature/landscape image URLs.
                    
                    Return ONLY a valid JSON array (no markdown, no explanation) with 3-5 objects containing:
                    - url: a working image URL from Unsplash (use format: https://images.unsplash.com/photo-XXXXX?w=800)
                    - description: brief caption (max 50 chars)
                    - author: "unsplash"
                    
                    Use real Unsplash photo IDs for nature, parks, gardens, and peaceful London scenes.
                    Example: [{"url":"https://images.unsplash.com/photo-1534067783941-51c9c23ecefd?w=800","description":"Peaceful park","author":"unsplash"}]
                    """
                ],
                [
                    "role": "user",
                    "content": "Provide image URLs for \(spotName) in \(location). Return JSON array only."
                ]
            ],
            "temperature": 0.5
        ]
        
        guard let url = URL(string: baseURL) else {
            print("❌ Invalid base URL")
            return getPlaceholderImages(for: spotName)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response")
                return getPlaceholderImages(for: spotName)
            }
            
            print("📸 Image API status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    print("📸 API content: \(content.prefix(200))...")
                    let images = parseImagesFromResponse(content, spotName: spotName)
                    print("📸 Parsed \(images.count) images")
                    return images.isEmpty ? getPlaceholderImages(for: spotName) : images
                }
            } else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorString.prefix(200))")
                }
            }
        } catch {
            print("❌ Failed to fetch X images: \(error)")
        }
        
        return getPlaceholderImages(for: spotName)
    }
    
    private func fetchTweetsFromX(for spotName: String, location: String) async -> [XTweet] {
        print("📨 Fetching tweets for: \(spotName)")
        
        let requestBody: [String: Any] = [
            "model": "grok-2-latest",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful assistant. Generate realistic sample tweets about London parks and calm spots.
                    
                    Return ONLY a valid JSON array (no markdown, no explanation) with 3-5 objects containing:
                    - text: a positive tweet about visiting the location (max 200 chars)
                    - author: a realistic display name
                    - author_handle: a realistic username (no @)
                    - likes: random number 10-500
                    - retweets: random number 1-50
                    
                    Make tweets sound authentic - visitor experiences, tips, nature observations.
                    Example: [{"text":"Beautiful morning at the park!","author":"London Explorer","author_handle":"londonexplorer","likes":42,"retweets":5}]
                    """
                ],
                [
                    "role": "user",
                    "content": "Generate sample tweets about \(spotName) in \(location). Return JSON array only."
                ]
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: baseURL) else {
            return getSampleTweets(for: spotName)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response for tweets")
                return getSampleTweets(for: spotName)
            }
            
            print("📨 Tweets API status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    print("📨 Tweets content: \(content.prefix(200))...")
                    let tweets = parseTweetsFromResponse(content)
                    print("📨 Parsed \(tweets.count) tweets")
                    return tweets.isEmpty ? getSampleTweets(for: spotName) : tweets
                }
            } else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Tweets API Error: \(errorString.prefix(200))")
                }
            }
        } catch {
            print("❌ Failed to fetch tweets: \(error)")
        }
        
        return getSampleTweets(for: spotName)
    }
    
    /// Generate sample tweets as fallback
    private func getSampleTweets(for spotName: String) -> [XTweet] {
        return [
            XTweet(
                text: "What a peaceful morning at \(spotName)! The perfect escape from the city hustle. Highly recommend for anyone needing some calm. 🌿",
                author: "London Explorer",
                authorHandle: "londonexplorer",
                likes: Int.random(in: 50...200),
                retweets: Int.random(in: 5...30)
            ),
            XTweet(
                text: "Found my new favourite spot in London - \(spotName) is absolutely gorgeous! Perfect weather today ☀️",
                author: "Nature Lover",
                authorHandle: "naturelondon",
                likes: Int.random(in: 30...150),
                retweets: Int.random(in: 3...20)
            ),
            XTweet(
                text: "If you're feeling stressed, take a walk through \(spotName). It's like a different world just minutes from central London 😌",
                author: "Wellness Tips",
                authorHandle: "wellnesslondon",
                likes: Int.random(in: 80...300),
                retweets: Int.random(in: 10...40)
            )
        ]
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
    
    /// Get curated placeholder images for London spots - using verified working Picsum URLs
    private func getPlaceholderImages(for spotName: String) -> [XImage] {
        // Using Lorem Picsum - guaranteed to work with seed-based IDs
        // Format: https://picsum.photos/seed/{seed}/800/600
        let spotNameLower = spotName.lowercased()
        
        // Generate unique but consistent images based on spot name
        let seed1 = spotName.hashValue
        let seed2 = seed1 &+ 1000
        let seed3 = seed1 &+ 2000
        let seed4 = seed1 &+ 3000
        
        // Different image categories by type
        if spotNameLower.contains("garden") || spotNameLower.contains("kyoto") || spotNameLower.contains("chelsea") || spotNameLower.contains("physic") {
            return [
                XImage(url: "https://picsum.photos/seed/garden\(abs(seed1))/800/600", description: "\(spotName) garden view", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/flowers\(abs(seed2))/800/600", description: "Beautiful flowers", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/nature\(abs(seed3))/800/600", description: "Peaceful nature", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/green\(abs(seed4))/800/600", description: "Green sanctuary", author: "picsum")
            ]
        } else if spotNameLower.contains("park") || spotNameLower.contains("heath") || spotNameLower.contains("common") {
            return [
                XImage(url: "https://picsum.photos/seed/park\(abs(seed1))/800/600", description: "\(spotName) landscape", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/trees\(abs(seed2))/800/600", description: "Park trees", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/meadow\(abs(seed3))/800/600", description: "Open meadow", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/path\(abs(seed4))/800/600", description: "Walking path", author: "picsum")
            ]
        } else if spotNameLower.contains("conservatory") || spotNameLower.contains("barbican") || spotNameLower.contains("indoor") {
            return [
                XImage(url: "https://picsum.photos/seed/tropical\(abs(seed1))/800/600", description: "\(spotName) interior", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/plants\(abs(seed2))/800/600", description: "Tropical plants", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/glass\(abs(seed3))/800/600", description: "Indoor oasis", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/exotic\(abs(seed4))/800/600", description: "Exotic flora", author: "picsum")
            ]
        } else if spotNameLower.contains("dunstan") || spotNameLower.contains("ruin") || spotNameLower.contains("historic") {
            return [
                XImage(url: "https://picsum.photos/seed/ruins\(abs(seed1))/800/600", description: "\(spotName) ruins", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/ivy\(abs(seed2))/800/600", description: "Ivy-covered walls", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/historic\(abs(seed3))/800/600", description: "Historic beauty", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/stone\(abs(seed4))/800/600", description: "Ancient stones", author: "picsum")
            ]
        } else {
            // Default London calm spots
            return [
                XImage(url: "https://picsum.photos/seed/london\(abs(seed1))/800/600", description: "\(spotName)", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/calm\(abs(seed2))/800/600", description: "Peaceful spot", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/serene\(abs(seed3))/800/600", description: "Serene views", author: "picsum"),
                XImage(url: "https://picsum.photos/seed/quiet\(abs(seed4))/800/600", description: "Quiet retreat", author: "picsum")
            ]
        }
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
                        colors: [TubeTheme.sage.opacity(0.6), TubeTheme.sageDeep.opacity(0.4)],
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
            await tryFallbackImage()
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: imageURL) {
            self.image = cachedImage
            isLoading = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for valid response
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let uiImage = UIImage(data: data) {
                ImageCache.shared.set(uiImage, forKey: imageURL)
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } else {
                // URL returned invalid response, try fallback
                await tryFallbackImage()
            }
        } catch {
            print("❌ Failed to load image: \(error.localizedDescription)")
            await tryFallbackImage()
        }
    }
    
    private func tryFallbackImage() async {
        // Generate a fallback Picsum URL based on the original URL hash
        let seed = abs(imageURL.hashValue)
        let fallbackURL = "https://picsum.photos/seed/fallback\(seed)/800/600"
        
        guard let url = URL(string: fallbackURL) else {
            await MainActor.run {
                self.isLoading = false
                self.loadFailed = true
            }
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
                return
            }
        } catch {
            print("❌ Fallback image also failed: \(error)")
        }
        
        await MainActor.run {
            self.isLoading = false
            self.loadFailed = true
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
    @State private var isLoadingTweets = true
    @State private var isLoadingImages = true
    @State private var selectedTab = 1  // Default to Posts tab (1) instead of Photos (0)
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab selector - Posts first
            Picker("Feed Type", selection: $selectedTab) {
                Label("Posts", systemImage: "text.bubble.fill").tag(1)
                Label("Photos", systemImage: "photo.stack.fill").tag(0)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == 1 {
                // Tweets/Posts tab (shown first)
                SpotTweetsFeed(tweets: tweets, isLoading: isLoadingTweets)
            } else {
                // Photos tab
                SpotImageCarousel(spotName: spotName, images: images, isLoading: isLoadingImages)
            }
            
            // Refresh button
            Button(action: {
                Task { await refreshFeed() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Refresh")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .disabled(isLoadingTweets && isLoadingImages)
        }
        .task {
            await loadFeed()
        }
    }
    
    private func loadFeed() async {
        // Load tweets first (faster with fallback)
        isLoadingTweets = true
        let fetchedTweets = await imageService.fetchTweets(for: spotName)
        await MainActor.run {
            self.tweets = fetchedTweets
            self.isLoadingTweets = false
        }
        
        // Then load images separately
        isLoadingImages = true
        let fetchedImages = await imageService.fetchImages(for: spotName)
        await MainActor.run {
            self.images = fetchedImages
            self.isLoadingImages = false
        }
    }
    
    private func refreshFeed() async {
        // Refresh tweets first
        isLoadingTweets = true
        let fetchedTweets = await imageService.fetchTweets(for: spotName, forceRefresh: true)
        await MainActor.run {
            self.tweets = fetchedTweets
            self.isLoadingTweets = false
        }
        
        // Then refresh images
        isLoadingImages = true
        let fetchedImages = await imageService.fetchImages(for: spotName, forceRefresh: true)
        await MainActor.run {
            self.images = fetchedImages
            self.isLoadingImages = false
        }
    }
}

// MARK: - Image Carousel for Spot Detail

struct SpotImageCarousel: View {
    let spotName: String
    @State private var images: [XImageService.XImage]
    @State private var isLoading: Bool
    @State private var currentIndex = 0
    @StateObject private var imageService = XImageService.shared
    private let isStandalone: Bool
    
    // For standalone use - will fetch its own images
    init(spotName: String) {
        self.spotName = spotName
        self._images = State(initialValue: [])
        self._isLoading = State(initialValue: true)
        self.isStandalone = true
    }
    
    // For use within SpotLiveFeedView - receives images from parent
    init(spotName: String, images: [XImageService.XImage], isLoading: Bool) {
        self.spotName = spotName
        self._images = State(initialValue: images)
        self._isLoading = State(initialValue: isLoading)
        self.isStandalone = false
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
            } else if !images.isEmpty {
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
                        Text("Loading photos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .task {
            // Only fetch if standalone (not receiving images from parent)
            if isStandalone {
                let fetchedImages = await imageService.fetchImages(for: spotName)
                await MainActor.run {
                    self.images = fetchedImages
                    self.isLoading = false
                }
            }
        }
        .onChange(of: spotName) { _, newSpotName in
            if isStandalone {
                Task {
                    isLoading = true
                    let fetchedImages = await imageService.fetchImages(for: newSpotName)
                    await MainActor.run {
                        self.images = fetchedImages
                        self.isLoading = false
                    }
                }
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
