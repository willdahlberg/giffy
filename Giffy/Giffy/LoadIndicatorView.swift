import UIKit

// View that displays a loading indicator. Meant to be used in a collection view.

class LoadIndicatorView: UICollectionReusableView {
  static let reuseIdentifier = String(describing: self)
  struct Constants {
    static let height: CGFloat = 64
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    let indicator = UIActivityIndicatorView(style: .large)
    indicator.startAnimating()
    addSubview(indicator)
    indicator.autoCenterInSuperview()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
