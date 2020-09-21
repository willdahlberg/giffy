import Foundation
import CoreGraphics
import QuickLook

// Representation of a unique remote image, including a small version URL and title. Also conforms to QLPreviewItem to be previewable by Quick Look.

public class RemoteImage: NSObject, QLPreviewItem {
  public let smallURL: URL
  public let smallSize: CGSize
  public let originalURL: URL
  public let title: String
  public let identifier: String

  // QLPreviewItem
  public var previewItemURL: URL?
  public var previewItemTitle: String? { title }

  init(smallURL: URL, smallSize: CGSize, originalURL: URL, title: String, identifier: String) {
    self.smallURL = smallURL
    self.smallSize = smallSize
    self.originalURL = originalURL
    self.title = title
    self.identifier = identifier
    super.init()
  }

  public override var hash: Int {
    identifier.hash
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let rhs = object as? RemoteImage else { return false }
    return hash == rhs.hash && smallURL == rhs.smallURL && smallSize == rhs.smallSize && originalURL == rhs.originalURL && title == rhs.title
  }
}
