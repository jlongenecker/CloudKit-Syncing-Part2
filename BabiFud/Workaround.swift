/*
* Copyright (c) 2014 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import Foundation
import UIKit
import CloudKit
import CoreLocation

func upload(db: CKDatabase,
  imageName: String,
  placeName: String,
  latitude:  CLLocationDegrees,
  longitude: CLLocationDegrees,
  changingTable : ChangingTableLocation,
  seatType:  SeatingType,
  healthy: Bool,
  kidsMenu: Bool,
  ratings: [UInt]) {
    let imURL = NSBundle.mainBundle().URLForResource(imageName, withExtension: "jpeg")
    let coverPhoto = CKAsset(fileURL: imURL!)
    let location = CLLocation(latitude: latitude, longitude: longitude)
    
    let establishment = CKRecord(recordType: "Establishment")
    establishment.setObject(coverPhoto, forKey: "CoverPhoto")
    establishment.setObject(placeName, forKey: "Name")
    establishment.setObject(location, forKey: "Location")
    establishment.setObject(changingTable.toRaw(), forKey: "ChangingTable")
    establishment.setObject(changingTable.toRaw(), forKey: "SeatingType")
    establishment.setObject(healthy, forKey: "HealthyOption")
    establishment.setObject(kidsMenu, forKey: "KidsMenu")
    
    
    db.saveRecord(establishment) { record, error in
      if error != nil {
        print("error setting up record \(error)")
        return
      }
      print("saved: \(record)")
      for rating in ratings {
        let ratingRecord = CKRecord(recordType: "Rating")
        ratingRecord.setObject(rating, forKey: "Rating")
        
        let ref = CKReference(record: record!, action: CKReferenceAction.DeleteSelf)
        ratingRecord.setObject(ref, forKey: "Establishment")
        db.saveRecord(ratingRecord) { record, error in
          if error != nil {
            print("error setting up record \(error)")
            return
          }
        }
      }
      
    }
}

func uploadSampleData() {
  let container = CKContainer.defaultContainer()
  let db = container.publicCloudDatabase
  
  //Apple Campus location = 37.33182, -122.03118
  upload(db, imageName: "pizza", placeName: "Caesar's Pizza Palace", latitude: 37.332, longitude: -122.03, changingTable: ChangingTableLocation.Womens, seatType: SeatingType.HighChair | SeatingType.Booster, healthy: false, kidsMenu: true, ratings: [0, 1, 2])
  upload(db, imageName: "chinese", placeName: "King Wok", latitude: 37.1, longitude: -122.1, changingTable: ChangingTableLocation.None, seatType: SeatingType.HighChair, healthy: true, kidsMenu: false, ratings: [])
  upload(db, imageName: "steak", placeName: "The Back Deck", latitude: 37.4, longitude: -122.03, changingTable: ChangingTableLocation.Womens | ChangingTableLocation.Mens, seatType: SeatingType.HighChair | SeatingType.Booster, healthy: true, kidsMenu: true, ratings: [5, 5, 4])
  upload(db, imageName: "burgers", placeName: "Five Guys", latitude: 37.335, longitude: -122.028, changingTable: ChangingTableLocation.Family, seatType: SeatingType.HighChair, healthy: false, kidsMenu: true, ratings: [5, 5, 5, 5, 4, 2, 1, 1])
  upload(db, imageName: "falafel", placeName: "Falafel King", latitude: 37.310, longitude: -122.03, changingTable: ChangingTableLocation.None, seatType: SeatingType.None, healthy: true, kidsMenu: false, ratings: [3, 3, 4])
  upload(db, imageName: "coffee", placeName: "Common Coffee", latitude: 37.26, longitude: -122.038, changingTable: ChangingTableLocation.Mens, seatType: SeatingType.Booster, healthy: true, kidsMenu: false, ratings: [5, 4, 2])
  upload(db, imageName: "vietnamese", placeName: "Sapa", latitude: 37.6, longitude: -122.026, changingTable: ChangingTableLocation.None, seatType: SeatingType.Booster | SeatingType.HighChair, healthy: true, kidsMenu: true, ratings: [])
  upload(db, imageName: "italian", placeName: "Lolas", latitude: 37.0, longitude: -121.9, changingTable: ChangingTableLocation.Womens, seatType: SeatingType.HighChair | SeatingType.Booster, healthy: false, kidsMenu: false, ratings: [3, 3, 5, 1])
}
