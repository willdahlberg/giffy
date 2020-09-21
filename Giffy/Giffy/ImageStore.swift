import Foundation

// Simple gif download and cache management.

class ImageStore {
  static let shared = ImageStore()

  private let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CachedOriginals", isDirectory: true)
  private var downloadTasks: [String: URLSessionDataTask] = [:]

  private init() {
    if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
      do {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: false, attributes: nil)
      } catch {
        fatalError("Couldn't create directory to store images.")
      }
    }
  }

  private func cacheFileURLFor(remoteImage: RemoteImage) -> URL {
    return cacheDirectory.appendingPathComponent(remoteImage.identifier).appendingPathExtension(remoteImage.originalURL.pathExtension)
  }

  /// Downloads a RemoteImage to disk and hands back the local file url, or just returns if it is already in the local disk cache or is currently being downloaded.
  /// - Parameters:
  ///   - remoteImage: The remote image to download to disk.
  ///   - didLoadHandler: Called with the file URL on disk for the downloaded image.
  func downloadImageIfNeededFor(remoteImage: RemoteImage, didLoadHandler: @escaping (URL) -> Void) {
    guard cachedImageURLFor(remoteImage: remoteImage) == nil, downloadTasks[remoteImage.identifier] == nil else { return }

    let task = URLSession.shared.dataTask(with: remoteImage.originalURL) { [weak self] (data, response, error) in
      guard let strongSelf = self else { return }

      strongSelf.downloadTasks.removeValue(forKey: remoteImage.identifier)
      guard let data = data else { return }

      let newFileURL = strongSelf.cacheFileURLFor(remoteImage: remoteImage)
      if FileManager.default.createFile(atPath: newFileURL.path, contents: data, attributes: nil) {
        DispatchQueue.main.async {
          didLoadHandler(newFileURL)
        }
      }
    }

    downloadTasks[remoteImage.identifier] = task
    task.resume()
  }

  /// Retrieves the file URL for an existing cached image.
  /// - Parameter remoteImage: The remote image to retrieve the corresponding file URL for.
  /// - Returns: A valid file URL or nil if it's not currently in the disk cache.
  func cachedImageURLFor(remoteImage: RemoteImage) -> URL? {
    let cacheURL = cacheFileURLFor(remoteImage: remoteImage)
    guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }

    return cacheURL
  }

  /// Clears the entire cache.
  func clearCache() {
    try? FileManager.default.removeItem(at: cacheDirectory)
  }
}
