# Giffy

A simple iOS app to search for and view animated gifs from Giphy.

## Overview

Giffy shows a single view controller that displays a search bar at the top along with a collection view for presenting results.

Some notable features:

- Search-as-you-type is implemented, with a 1 second delay to debounce keystrokes.
- Small versions of the gifs are displayed in a masonry style gallery.
- Tapping on an image shows the original in fullscreen via Quick Look, which has functionality to share the image from there.
- A simple paging mechanism is implemented by scrolling to the bottom of the current results and letting it settle there.
- The UI is set up to look good in both light- and dark mode and take advantage of different screen widths as appropriate. 
- Some details added in the UI: Rounded and bordered cells that highlights on tap-down, transition into Quick Look shows a zooming animation (currently looks best if the image is already in the disk cache).

Below is an overview of each class in the project and some implementation details:

### AppDelegate
UIApplicationDelegate created by the iOS project template. The only modification is the addition of `applicationWillTerminate(_:)` to clear the on disk image cache when the app quits.

### SceneDelegate
UIWindowSceneDelegate created by the iOS project template. Unmodified.

### MainViewController
The root view controller of the app instantiated by the storyboard from the template. Simply inserts an `ImageSearchViewController` on load.

### ImageSearchViewController
The bulk of the UI is handled in this view controller. It adds a UISearchBar at the top as a navigation item as well as a UICollectionView covering the whole view for displaying the results. A search is performed as you type with a slight delay to avoid excessive number of queries. `GiphySearchController` is used to retrieve results in the form of `RemoteImage` objects. These objects are declared as the items in the data source for the collection view, so they are used directly to create and apply a diffable snapshot.

The results are displayed in the collection view using a custom layout that fills the width of the view with fixed sized columns. The aspect ratio of the images are kept intact, so the height varies per cell and a fixed space is used between each. [Nuke](https://github.com/kean/Nuke) is used to download a small version of the gif and display in each cell as they appear.

Tapping on a cell uses Quick Look to view the original gif. To avoid downloading originals for results that are never viewed in fullscreen, `ImageStore` is used to download the files to a temporary location on tap. The data is saved to file since Quick Look requires a valid file URL to display.

One hundred results are retrieved on a search, and subsequent pages can be brought in by scrolling (and letting it settle) at the bottom.

### GiphySearchController
Handles search queries to Giphy via a `URLSessionTask`. The only public interface of this class is `performSearch(searchString:offset:maxResults:resultsHandler:)` which makes a request for a given search string, offset within the results, and a max number of results. Results are then asynchronously handed to the resultsHandler. If a search is performed while a previous one is still outstanding, the current one is cancelled and replaced with the new one.

### ImageCell
A `UICollectionViewCell` subclass to display a single animated image (using `GIFImageView`). The image has some styling applied to its layer to add a border and round corners.

### LoadIndicatorView
A `UICollectionReusableView` subclass to display a spinning load indicator in the collection view.

### RemoteImage
A data structure representing a single result in a search query. Includes information such as urls for a small version and the original.

### ImageStore
Manages downloading an saving originals of for `RemoteImage` objects. This is used so that file URLs can be handed to Quick Look for fullscreen viewing.

## Requirements

Developed using:

- Xcode 11.6
- iOS 13.5 simulators
- Swift 5

## How to build and run

Clone or download the repository and open Giffy.xcodeproj. The project builds an iOS app and any iPhone or iPad simulator target is good to run on. The project was developed using Xcode 11.6 and tested on iOS 13.5 simulators.

To try the app, build and run in a simulator and type a search string into the search bar.

## Dependencies

Giffy uses the following Swift Package dependencies:

- [PureLayout](https://github.com/PureLayout/PureLayout/) for setting up auto layout constraints in a simple way.
- [Gifu](https://github.com/kaishin/Gifu.git)  for animating gif images.
- [Nuke](https://github.com/kean/Nuke) for downloading and displaying search results.

## Next steps

Here are some things I would consider doing next if I spent more time on the project:
- Make `GiphySearchController` more dynamic in terms of the format of JSON it can handle. I noticed for instance not all results have a small version of the gif, and that is currently not handled.
- Write unit tests. A good candidate is the above – to write tests that verify the expected `RemoteImage` objects are created given various forms of JSON.
- Tapping on an image to view in full screen would look nicer if the original was already downloaded and available. I would think of ways to improve the case when the original isn't already cached, perhaps by showing the already available low resolution version until the higher resolution is ready.  
- Currently Nuke is used to download and display small versions of the images in the collection view, and my own `ImageStore` to download the originals to be viewed by Quick Look. I would consider unifying it so that both places uses the same download and caching mechanism.
- Consider splitting up result pages in separate sections. Since the collection view queries layout objects per section, I can imagine there are performance gains to be had if there's more granularity to the structure there.
- Make the load-more interaction more sophisticated. Currently the spinner always shows at the bottom as if it is loading more results, but another query is only performed if the scroll view settles at the bottom. There is also no notion of whether there are more results to load or not, which is information provided by the Giphy search end-point and should be used.
- Add localization.
