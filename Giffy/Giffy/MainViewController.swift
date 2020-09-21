import UIKit
import PureLayout

class MainViewController: UINavigationController {
  override func viewDidLoad() {
    super.viewDidLoad()

    // The root VC just holds the single search controller to display at launch.
    self.viewControllers = [ImageSearchViewController()]
  }
}

