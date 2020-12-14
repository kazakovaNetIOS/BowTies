import UIKit
import CoreData

class ViewController: UIViewController {

  var window: UIWindow?

  // MARK: - IBOutlets
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var ratingLabel: UILabel!
  @IBOutlet weak var timesWornLabel: UILabel!
  @IBOutlet weak var lastWornLabel: UILabel!
  @IBOutlet weak var favoriteLabel: UILabel!
  @IBOutlet weak var wearButton: UIButton!
  @IBOutlet weak var rateButton: UIButton!

  // MARK: - Properties
  var managedContext: NSManagedObjectContext?
  var currentBowTie: BowTie?

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    managedContext = appDelegate?.persistentContainer.viewContext

    insertSampleData()

    let request: NSFetchRequest<BowTie> = BowTie.fetchRequest()
    guard let firstTitle = segmentedControl.titleForSegment(at: 0) else { return }
    request.predicate = NSPredicate(format: "%K = %@",
                                    argumentArray: [#keyPath(BowTie.searchKey), firstTitle])

    do {
      let results = try managedContext?.fetch(request)
      currentBowTie = results?.first

      populate(bowTie: results?.first)
    } catch let error as NSError {
      print("Could not fetch \(error), \(error.userInfo)")
    }
  }

  // MARK: - IBActions

  @IBAction func segmentedControl(_ sender: UISegmentedControl) {

  }

  @IBAction func wear(_ sender: UIButton) {
    guard let currentBowTie = self.currentBowTie else { return }

    let times = currentBowTie.timesWorn
    currentBowTie.timesWorn = times + 1
    currentBowTie.lastWorn = Date()

    do {
      try managedContext?.save()
      populate(bowTie: currentBowTie)
    } catch let error as NSError {
      print("Could not fetch \(error), \(error.userInfo)")
    }
  }

  @IBAction func rate(_ sender: UIButton) {
    let alert = UIAlertController(title: "New Rating",
                                  message: "Rate this bow tie",
                                  preferredStyle: .alert)
    alert.addTextField { (textField) in
      textField.keyboardType = .decimalPad
    }

    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .cancel)
    let saveAction = UIAlertAction(title: "Save",
                                   style: .default) { [weak self] (action) in
      if let textField = alert.textFields?.first {
        self?.update(rating: textField.text)
      }
    }

    alert.addAction(cancelAction)
    alert.addAction(saveAction)

    present(alert, animated: true)
  }
}

// MARK: - Private

private extension ViewController {
  func insertSampleData() {
    let fetch: NSFetchRequest<BowTie> = BowTie.fetchRequest()
    fetch.predicate = NSPredicate(format: "searchKey != nil")

    let count = (try? managedContext?.count(for: fetch)) ?? 0

    if count > 0 {
      return
    }

    guard let path = Bundle.main.path(forResource: "SampleData", ofType: "plist"),
          let managedContext = self.managedContext else { return }

    let dataArray = NSArray(contentsOfFile: path) ?? []
    for dict in dataArray {
      guard let entity = NSEntityDescription.entity(forEntityName: "BowTie",
                                                    in: managedContext) else { continue }
      let bowTie = BowTie(entity: entity, insertInto: managedContext)
      guard let btDict = dict as? [String: Any],
            let dictId = btDict["id"] as? String,
            let colorDict = btDict["tintColor"] as? [String: Any],
            let imageName = btDict["imageName"] as? String,
            let timesNumber = btDict["timesWorn"] as? NSNumber,
            let isFavorite = btDict["isFavorite"] as? Bool,
            let url = btDict["url"] as? String else { continue }
      bowTie.id = UUID(uuidString: dictId)
      bowTie.name = btDict["name"] as? String
      bowTie.searchKey = btDict["searchKey"] as? String
      bowTie.rating = btDict["rating"] as? Double ?? 0
      bowTie.tintColor = UIColor.color(dict: colorDict)

      let image = UIImage(named: imageName)
      bowTie.photoData = image?.pngData()

      bowTie.lastWorn = btDict["lastWorn"] as? Date
      bowTie.timesWorn = timesNumber.int32Value
      bowTie.isFavorite = isFavorite
      bowTie.url = URL(string: url)
    }

    try? managedContext.save()
  }

  func populate(bowTie: BowTie?) {
    guard let bowTie = bowTie,
          let imageData = bowTie.photoData,
          let lastWorn = bowTie.lastWorn,
          let tintColor = bowTie.tintColor as? UIColor else {
      return
    }

    imageView.image = UIImage(data: imageData)
    nameLabel.text = bowTie.name
    ratingLabel.text = "Rating: \(bowTie.rating)/5"

    timesWornLabel.text = "# times worn: \(bowTie.timesWorn)"

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .none

    lastWornLabel.text = "Last worn: " + dateFormatter.string(from: lastWorn)

    favoriteLabel.isHidden = !bowTie.isFavorite
    view.tintColor = tintColor
  }

  func update(rating: String?) {
    guard let ratingString = rating,
          let rating = Double(ratingString) else { return }

    do {
      currentBowTie?.rating = rating
      try managedContext?.save()
      populate(bowTie: currentBowTie)
    } catch let error as NSError {
      print("Could not save \(error), \(error.userInfo)")
    }
  }
}

// MARK: - UIColor extension

private extension UIColor {
  static func color(dict: [String: Any]) -> UIColor? {
    guard let red = dict["red"] as? NSNumber,
          let green = dict["green"] as? NSNumber,
          let blue = dict["blue"] as? NSNumber else { return nil }

    return UIColor(red: CGFloat(truncating: red) / 255.0,
                   green: CGFloat(truncating: green) / 255.0,
                   blue: CGFloat(truncating: blue) / 255.0,
                   alpha: 1)
  }
}
