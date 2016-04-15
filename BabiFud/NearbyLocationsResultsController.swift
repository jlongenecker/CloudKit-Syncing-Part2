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

protocol NearbyLocationsResultsControllerDelegate {
  //add delegate methods here
    func willBeginUpdating()
    func establishmentAdd(establishment: Establishment, index: Int)
    func establishmentUpdated(establishment: Establishment, index: Int)
    func didEndUpdating(error: NSError!)
}

class NearbyLocationsResultsController {
    
    
   
  //1
  let db: CKDatabase //1
    
   //2
  var predicate: NSPredicate?
    //3
  let delegate: NearbyLocationsResultsControllerDelegate
    //4
  var results = [Establishment]()
  //5
    
    
    var resultsLimit = 2
    var cursor: CKQueryCursor!
    var startedGettingResults = false
    let RecordType = "Establishment"
    var inProgress = false
    
    
  init(delegate: NearbyLocationsResultsControllerDelegate) {
    self.delegate = delegate
    db = CKContainer.defaultContainer().publicCloudDatabase
     print("NearbyLocationsResultsController called")
  }
    
    
    
    func start() {
        //1 
        if inProgress {
            return
        }
        inProgress = true
        //2
        let query = CKQuery(recordType: RecordType, predicate: predicate!)
        let queryOp = CKQueryOperation(query: query)
        
        sendOperation(queryOp)
        print("NearbyLocationsResultsController Start method called")
    }
    
    
    
    func recordFetch(record:CKRecord!) {
        print("Record Fetch Begins")
        //1
        if !startedGettingResults {
            startedGettingResults = true
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate.willBeginUpdating()
            }
        }
        var index = NSNotFound
        var e: Establishment!
        var newItem = true
        
        //2
        for (idx,value) in (results).enumerate() {
            if value.record.recordID == record.recordID {
                index = idx
                e = value
                e.record = record
                newItem = false
                break
            }
        }
        //3 
        if index == NSNotFound {
            e = Establishment(record: record, database: db)
            results.append(e)
            index = results.count - 1
        }
        dispatch_async(dispatch_get_main_queue()) {
            //4
            if newItem {
                self.delegate.establishmentAdd(e, index: index)
            } else {
                self.delegate.establishmentUpdated(e, index: index)
            }
        }
        
    }
    
    func queryCompleted(cursor: CKQueryCursor!, error: NSError!) {
        startedGettingResults = false
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate.didEndUpdating(error)
        }
    }
    
    func fetchNextResults(cursor: CKQueryCursor) {
        let queryOp = CKQueryOperation(cursor: cursor)
        sendOperation(queryOp)
    }
    
    func sendOperation(queryOp: CKQueryOperation) {
        //1
        queryOp.queryCompletionBlock = {
            cursor, error in
            //2
            self.queryCompleted(cursor, error: error)
            if (cursor != nil) {
                //3
                self.fetchNextResults(cursor!)
                print("Cursor: \(cursor)")
            } else {
                //4
                self.inProgress = false
            }
        }
        
        queryOp.recordFetchedBlock = { record in
            //5 
            self.recordFetch(record)
        }
        
        queryOp.resultsLimit = resultsLimit
        //6
        startedGettingResults = false
        db.addOperation(queryOp)
        
    }
    
   
}
