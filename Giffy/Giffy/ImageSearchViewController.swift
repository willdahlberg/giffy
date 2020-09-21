import Foundation
import UIKit
import QuickLook
import Nuke

class ImageSearchViewController: UIViewController, UISearchBarDelegate, UICollectionViewDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
  struct Constants {
    static let typeSearchDelay: TimeInterval = 1
    static let resultsPerPage = 100
  }

  enum Section { case main }  // Only one section needed for now.

  let searchBar = UISearchBar()
  var resultsCollectionView: UICollectionView!
  var dataSource: UICollectionViewDiffableDataSource<Section, RemoteImage>!
  let giphySearchController = GiphySearchController()
  //let imageStore = ImageStore()
  var quickLookObserver: NSKeyValueObservation?
  var typeSearchDelayTimer: Timer?

  override func loadView() {
    super.loadView()

    ImagePipeline.Configuration.isAnimatedImageDataEnabled = true

    searchBar.placeholder = "Search Giphy…"
    searchBar.delegate = self
    navigationItem.titleView = searchBar

    resultsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
    view.addSubview(resultsCollectionView)
    resultsCollectionView.autoPinEdgesToSuperviewEdges()
    resultsCollectionView.backgroundColor = .systemBackground
    resultsCollectionView.alwaysBounceVertical = true
    resultsCollectionView.keyboardDismissMode = .onDrag
    resultsCollectionView.delegate = self

    // Register ImageCell for each result in the search and the LoadIndicatorView as a supplementary view at the bottom to indicate more results are coming.
    resultsCollectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
    resultsCollectionView.register(LoadIndicatorView.self, forSupplementaryViewOfKind: LoadIndicatorView.reuseIdentifier, withReuseIdentifier: LoadIndicatorView.reuseIdentifier)

    configureDataSource()
  }

  // MARK: UICollectionViewDataSource

  func configureDataSource() {
    dataSource = UICollectionViewDiffableDataSource(collectionView: resultsCollectionView, cellProvider: { [weak self] (collectionView, indexPath, item) -> UICollectionViewCell? in
      guard let strongSelf = self else { return nil }
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseIdentifier, for: indexPath) as! ImageCell

      // Use Nuke to load the small version into the imageView. Nuke handles caching per URL.
      Nuke.loadImage(with: strongSelf.dataSource.itemIdentifier(for: indexPath)!.smallURL, into: cell.imageView)

      return cell
    })

    dataSource.supplementaryViewProvider = { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
      guard let supplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind, for: indexPath) as? LoadIndicatorView else { fatalError("Failed to create new LoadIndicatorView") }
      return supplementaryView
    }
  }

  // MARK: UICollectionViewDelegate

  // Show the original gif in a QLPreviewController on tap of a cell.
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let qlPreviewController = QLPreviewController()
    if UIDevice.current.userInterfaceIdiom == .pad {
      qlPreviewController.modalPresentationStyle = .pageSheet
    }
    qlPreviewController.dataSource = self
    qlPreviewController.delegate = self
    qlPreviewController.currentPreviewItemIndex = indexPath.item

    // There's no need to observe the initial value index, since the index starts at some high value and then immediately changes to whatever we have set as the current index.
    quickLookObserver = qlPreviewController.observe(\.currentPreviewItemIndex, options: [.new] ) { [weak self, weak qlPreviewController] _, change in
      guard let strongSelf = self, let index = change.newValue else { return }
      let snapshot = strongSelf.dataSource.snapshot()
      let result = snapshot.itemIdentifiers[index]

      // Download the currently viewed image as well as the previous and next ones if needed. That way swiping to the next or previous page in Quick Look likely already has the file ready to display.
      ImageStore.shared.downloadImageIfNeededFor(remoteImage: result) { url in
        qlPreviewController?.reloadData()
      }

      if index > 0 {
        let previousResult = snapshot.itemIdentifiers[index - 1]
        ImageStore.shared.downloadImageIfNeededFor(remoteImage: previousResult) { url in
          qlPreviewController?.reloadData()
        }
      }

      if index < snapshot.itemIdentifiers.count - 1 {
        let nextResult = snapshot.itemIdentifiers[index + 1]
        ImageStore.shared.downloadImageIfNeededFor(remoteImage: nextResult) { url in
          qlPreviewController?.reloadData()
        }
      }
    }

    present(qlPreviewController, animated: true, completion: nil)
  }

  // MARK: Layout

  func createLayout() -> UICollectionViewCompositionalLayout {
    return UICollectionViewCompositionalLayout { [weak self] (section, environment) -> NSCollectionLayoutSection? in
      return self?.gallerySectionLayout(for: section, environment: environment)
    }
  }

  // Custom layout for a masonry style gallery with fixed width cells.
  private func gallerySectionLayout(for sectionIndex: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let insets = view.directionalLayoutMargins
    let cellWidth: CGFloat = GiphySearchController.smallFixedWidth  // Hard coded widths that match what is returned by Giphy for now.
    let contentWidth = environment.container.effectiveContentSize.width - insets.leading - insets.trailing
    let columnCount = Int(contentWidth / cellWidth)
    let spacing = (contentWidth - cellWidth * CGFloat(columnCount)) / CGFloat(columnCount - 1)
    var cellLayouts: [NSCollectionLayoutGroupCustomItem] = []
    var groupHeight: CGFloat = 0

    // Make custom layout items for all results, keeping track of the final height as we go.
    dataSource.snapshot().itemIdentifiers.indices.forEach { index in
      var cellOrigin: CGPoint = .zero
      let cellHeight = dataSource.snapshot().itemIdentifiers[index].smallSize.height
      let cellSize = CGSize(width: cellWidth, height: cellHeight)

      // The cell is nudged up to the right side of the one on the left, otherwise 0 if this is the leftmost column.
      let leftSideIndex = (index % columnCount) - 1
      if leftSideIndex > -1 {
        cellOrigin.x = cellLayouts[leftSideIndex].frame.maxX + spacing
      } else {
        cellOrigin.x = 0
      }

      // The cell is nudged up to the bottom of the one above, otherwise 0 if this is the first row.
      let aboveIndex = index - columnCount
      if aboveIndex > -1 {
        cellOrigin.y = cellLayouts[aboveIndex].frame.maxY + spacing
      } else {
        cellOrigin.y = 0
      }

      let item = NSCollectionLayoutGroupCustomItem(frame: CGRect(origin: cellOrigin, size: cellSize))
      cellLayouts.append(item)
      groupHeight = max(groupHeight, item.frame.maxY)
    }

    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(groupHeight))
    let groupLayout = NSCollectionLayoutGroup.custom(layoutSize: groupSize) { _ -> [NSCollectionLayoutGroupCustomItem] in
      cellLayouts
    }

    let section = NSCollectionLayoutSection(group: groupLayout)
    section.contentInsets.leading = insets.leading
    section.contentInsets.trailing = insets.trailing
    section.contentInsets.top = spacing

    // For now, always add a load indicator to the bottom of the section, to show the user that scrolling to the bottom will continue loading in results.
    let loadIndicatorSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LoadIndicatorView.Constants.height))
    let loadIndicator = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: loadIndicatorSize, elementKind: LoadIndicatorView.reuseIdentifier, alignment: .bottom)
    section.boundarySupplementaryItems = [loadIndicator]

    return section
  }

  // MARK: UISearchBarDelegate

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    performSearch()
  }

  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    typeSearchDelayTimer?.invalidate()

    // If the search bar is emptied, just clear the results immediately.
    guard !searchText.isEmpty else {
      dataSource.apply(NSDiffableDataSourceSnapshot<Section, RemoteImage>())
      return
    }

    typeSearchDelayTimer = Timer.scheduledTimer(withTimeInterval: Constants.typeSearchDelay, repeats: false, block: { [weak self] _ in
      self?.performSearch()
    })
  }

  func performSearch() {
    guard let searchString = searchBar.text else { return }
    giphySearchController.performSearch(searchString: searchString, offset: 0, maxResults: Constants.resultsPerPage) { [weak self] results in
      var snapshot = NSDiffableDataSourceSnapshot<Section, RemoteImage>()
      snapshot.appendSections([.main])
      snapshot.appendItems(results)
      self?.dataSource.apply(snapshot)
    }
  }

  // MARK: QLPreviewControllerDataSource

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    dataSource.snapshot().itemIdentifiers.count
  }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    let result = dataSource.snapshot().itemIdentifiers[index]

    // Set the previewItemURL if it isn't set already (QL is reloaded with this information available as originals are downloaded).
    if result.previewItemURL == nil {
      result.previewItemURL = ImageStore.shared.cachedImageURLFor(remoteImage: result)
    }

    return result
  }

  // MARK: QLPreviewControllerDelegate

  func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
    guard let itemIndex = dataSource.snapshot().indexOfItem(item as! RemoteImage) else { return nil }
    return resultsCollectionView.cellForItem(at: IndexPath(item: itemIndex, section: 0))
  }

  // MARK: UIScrollViewDelegate

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard let searchString = searchBar.text else { return }

    // Simple load-more interaction where another search query is performed if the scroll view settles at the bottom.
    if Int(scrollView.bounds.maxY - scrollView.adjustedContentInset.bottom) == Int(scrollView.contentSize.height) {
      var snapshot = dataSource.snapshot()
      let offset = snapshot.itemIdentifiers.count // The offset for loading more results is just the current number of items in the collection view.
      giphySearchController.performSearch(searchString: searchString, offset: offset, maxResults: Constants.resultsPerPage) { [weak self] results in
        snapshot.appendItems(results)
        self?.dataSource.apply(snapshot)
      }
    }
  }
}
