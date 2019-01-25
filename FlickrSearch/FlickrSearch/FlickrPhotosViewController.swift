/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

final class FlickrPhotosViewController: UICollectionViewController {
  // MARK: - Properties
  private let reuseIdentifier = "FlickrCell"
  private let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)
  private var searches = [FlickrSearchResults]()
  private let flickr = Flickr()
  private let itemsPerRow: CGFloat = 3
  private var selectedPhotos : [FlickrPhoto] = []
  private var shareLabel = UILabel()
  
  
  var largePhotoIndexpath: IndexPath? {
    didSet {
      var indexpaths: [IndexPath] = []
      
      if let largePhotoIndexpath = largePhotoIndexpath{
        indexpaths.append(largePhotoIndexpath)
      }
      
      if let oldValue = oldValue {
        indexpaths.append(oldValue)
      }
      
      collectionView.performBatchUpdates({
        self.collectionView.reloadItems(at: indexpaths)
      }) { _ in
        
        if let largePhotoIndexpath = self.largePhotoIndexpath {
          self.collectionView.scrollToItem(at: largePhotoIndexpath, at: UICollectionView.ScrollPosition.centeredVertically, animated: true)
        }
      }
      
    }
  }
 
  var sharing : Bool = false {
    
    didSet {
      collectionView.allowsMultipleSelection = sharing
      
      collectionView.selectItem(at: nil, animated: true, scrollPosition: [])
      selectedPhotos.removeAll()
      
      guard let shareButton = self.navigationItem.rightBarButtonItems?.first else{
        return
      }
      
      guard sharing else {
        self.navigationItem.setRightBarButton(shareButton, animated: true)
        return
      }
      
      if largePhotoIndexpath != nil {
        largePhotoIndexpath = nil
      }
      
      UpdateShareCountLabel()
      
      let sharingItem = UIBarButtonItem(customView: shareLabel)
      let items : [UIBarButtonItem] = [shareButton, sharingItem]
      
      navigationItem.setRightBarButtonItems(items, animated: true)
      
    }
  }
    
    @IBAction func share(_ sender: UIBarButtonItem) {
        
        guard !searches.isEmpty else {
            return
        }
        
        guard !selectedPhotos.isEmpty else {
            sharing.toggle()
            return
        }
        
        guard sharing else {
            return
        }
        
        let images : [UIImage] = selectedPhotos.compactMap { photo in
            
            if let thumbnail = photo.thumbnail{
                return thumbnail
            }
            return nil
        }
        
        guard !images.isEmpty else{
            return
        }
        
        let shareController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        shareController.completionWithItemsHandler = { _,_,_,_ in
            
            self.sharing = false
            self.selectedPhotos.removeAll()
            self.UpdateShareCountLabel()
            
        }
        
        shareController.popoverPresentationController?.barButtonItem = sender
        shareController.popoverPresentationController?.permittedArrowDirections = .any
        present(shareController, animated: true, completion: nil)
        
    }
    
    
  
}

// MARK: - Private
private extension FlickrPhotosViewController {
  
  
  func photo(for indexPath: IndexPath) -> FlickrPhoto {
    return searches[indexPath.section].searchResults[indexPath.row]
  }
  
  
  
  func fetchLargeImage(for indexpath: IndexPath , flickrPhoto : FlickrPhoto) {
    
    guard let cell = collectionView.cellForItem(at: indexpath) as? FlickrPhotoCell else{
      return
    }
    
  cell.activityIndicator.startAnimating()
    
    flickrPhoto.loadLargeImage { [weak self] result in
      
      guard let self = self else{
        return
      }
      
      switch result {
      case .results(let photo) :
        if indexpath == self.largePhotoIndexpath {
          cell.imageView.image = photo.largeImage
        }
      case .error(_):
        return
      }
    }
  }
  
  
  func UpdateShareCountLabel(){
    
    if sharing {
      shareLabel.text = "\(selectedPhotos.count) photos selected"
    }else {
      shareLabel.text = ""
    }
    
    shareLabel.textColor = themeColor
    
    UIView.animate(withDuration: 0.3) {
      self.shareLabel.sizeToFit()
    }
    
  }
  
}

// MARK: - UITextFieldDelegate
extension FlickrPhotosViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    let activityIndicator = UIActivityIndicatorView(style: .gray)
    textField.addSubview(activityIndicator)
    activityIndicator.frame = textField.bounds
    activityIndicator.startAnimating()
    
    flickr.searchFlickr(for: textField.text!) { searchResults in
      activityIndicator.removeFromSuperview()
      
      switch searchResults {
      case .error(let error) :
        print("Error Searching: \(error)")
      case .results(let results):
        print("Found \(results.searchResults.count) matching \(results.searchTerm)")
        self.searches.insert(results, at: 0)
        self.collectionView?.reloadData()
      }
    }
    
    textField.text = nil
    textField.resignFirstResponder()
    return true
  }

}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosViewController {
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return searches.count
  }
  
  override func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
    return searches[section].searchResults.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
  guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                      for: indexPath) as? FlickrPhotoCell else{
                                                        preconditionFailure("invalid cell type") }
              let flickrPhoto = photo(for: indexPath)
    
    cell.activityIndicator.stopAnimating()
    
    guard indexPath == largePhotoIndexpath else {
      cell.imageView.image = flickrPhoto.thumbnail
      return cell
    }
    
    guard flickrPhoto.largeImage == nil else{
      cell.imageView.image = flickrPhoto.largeImage
      return cell
    }
    
    cell.imageView.image = flickrPhoto.thumbnail
  fetchLargeImage(for: indexPath, flickrPhoto: flickrPhoto)
    
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    
    switch kind {
    case UICollectionView.elementKindSectionHeader:
      
      guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FlickrPhotoHeaderView", for: indexPath) as? FlickrPhotoHeaderView else {
        fatalError("invalid view type")
      }
      
      let searchTerm = searches[indexPath.section].searchTerm
      headerView.sectionTitleLabel.text = searchTerm
      return headerView
      
    default:
      assert(false, "invalid element type")
    }
    
  }
  
}
// MARK: - UICollectionViewDelegateFlowLayout
extension FlickrPhotosViewController: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    if indexPath == largePhotoIndexpath {
      let flickrPhoto = photo(for: indexPath)
      var size = collectionView.bounds.size
      size.height -= (sectionInsets.top + sectionInsets.bottom)
      size.width -= (sectionInsets.left + sectionInsets.right)
      return flickrPhoto.sizeToFillWidth(of: size)
    }
    
    
    let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
    let availableWidth = view.frame.width - paddingSpace
    let widthPerItem = availableWidth / itemsPerRow
    
    return CGSize(width: widthPerItem, height: widthPerItem)
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return sectionInsets.left
  }
}

extension FlickrPhotosViewController  {
 
  override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    
    guard !sharing else {
        return true
    }
    if largePhotoIndexpath == indexPath {
      largePhotoIndexpath = nil
    }
    else {
      largePhotoIndexpath = indexPath
    }
    
    return false
  }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard sharing else{
            return
        }
        
        let flickrPhoto = photo(for: indexPath)
        selectedPhotos.append(flickrPhoto)
        UpdateShareCountLabel()
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        guard sharing else {return}
        
        let flickrPhoto = photo(for: indexPath)
        if let index = selectedPhotos.firstIndex(of: flickrPhoto){
            selectedPhotos.remove(at: index)
            UpdateShareCountLabel()
        }
    }
}
