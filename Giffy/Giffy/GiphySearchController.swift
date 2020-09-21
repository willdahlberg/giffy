import Foundation
import CoreGraphics

// Interface to perform searches and handle returned results from Giphy in the form of `RemoteImage`s.

public class GiphySearchController {
  private static let searchEndPoint = "https://api.giphy.com/v1/gifs/search"
  private static let apiKey = "ZsUpUm2L6cVbvei347EQNp7HrROjbOdc"
  public static let smallFixedWidth: CGFloat = 100  // The static width of small versions of the gifs returned by Giphy.

  private var searchTask: URLSessionDataTask?

  /// Performs a search query to Giphy and returns the result as `RemoteImage`s.
  /// - Parameters:
  ///   - searchString: The search string to use.
  ///   - offset: An offset within the entire set of results to start at.
  ///   - maxResults: A max number of results to return from `offset`.
  ///   - resultsHandler: A handler to to deal with the resulting `RemoteImage`s.
  public func performSearch(searchString: String, offset: Int, maxResults: Int, resultsHandler: @escaping ([RemoteImage]) -> Void) {
    let request = requestFor(searchString: searchString, offset: offset, maxResults: maxResults)

    searchTask?.cancel()
    searchTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data else {
        print("Giphy search request failed: \(String(describing: error))")
        return
      }

      guard let json = try? JSONSerialization.jsonObject(with: data, options: .init()) as? [String: Any] else {
        print("Bad jason data in giphy response")
        return
      }

      let dataArray = json["data"] as! [[String: Any]]
      let results: [RemoteImage] = dataArray.compactMap { resultDict in
        // TODO: Make this hard coded parsing more dynamic to cover more possibilities in the returned JSON, for instance when a small version of the gif doesn't exist.
        guard let images = resultDict["images"] as? [String: Any],
          let fixedWidth = images["fixed_width_small"] as? [String: Any],
          let smallURLString = fixedWidth["url"] as? String,
          let smallURL = URL(string: smallURLString),
          let smallWidthString = fixedWidth["width"] as? String,
          let smallHeightString = fixedWidth["height"] as? String,
          let smallWidth = Int(smallWidthString),
          let smallHeight = Int(smallHeightString),
          let original = images["original"] as? [String: Any],
          let originalURLString = original["url"] as? String,
          let originalURL = URL(string: originalURLString),
          let title = resultDict["title"] as? String,
          let identifier = resultDict["id"] as? String else {
            print("Failed to parse result: \(resultDict)")
            return nil
        }

        return RemoteImage(smallURL: smallURL, smallSize: CGSize(width: smallWidth, height: smallHeight), originalURL: originalURL, title: title, identifier: identifier)
      }

      resultsHandler(results)
    }

    searchTask?.resume()
  }

  private func requestFor(searchString: String, offset: Int, maxResults: Int) -> URLRequest {
    var urlComponents = URLComponents(string: GiphySearchController.searchEndPoint)!
    urlComponents.queryItems = [.init(name: "api_key", value: GiphySearchController.apiKey), .init(name: "q", value: searchString), .init(name: "offset", value: String(offset)), .init(name: "limit", value: String(maxResults))]
    return URLRequest(url: urlComponents.url!)
  }
}
