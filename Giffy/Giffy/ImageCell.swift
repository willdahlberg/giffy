import Foundation
import UIKit
import Nuke
import Gifu

// See https://github.com/kean/Nuke-Gifu-Plugin
extension GIFImageView {
  public override func nuke_display(image: PlatformImage?) {
    prepareForReuse()
    if let data = image?.animatedImageData {
      animate(withGIFData: data)
    } else {
      self.image = image
    }
  }
}


class ImageCell: UICollectionViewCell {
  static let reuseIdentifier = String(describing: self)
  struct Constants {
    static let cornerRadius: CGFloat = 5
    static let borderWidth: CGFloat = 1
    static let borderColor = UIColor.systemFill.cgColor
  }

  let imageView = GIFImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    imageView.layer.borderWidth = Constants.borderWidth
    imageView.layer.borderColor = Constants.borderColor
    imageView.layer.cornerRadius = Constants.cornerRadius
    imageView.layer.masksToBounds = true

    contentView.addSubview(imageView)
    imageView.autoPinEdgesToSuperviewEdges()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isHighlighted: Bool {
    didSet {
      imageView.alpha = isHighlighted ? 0.5 : 1
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    imageView.prepareForReuse()
  }
}
