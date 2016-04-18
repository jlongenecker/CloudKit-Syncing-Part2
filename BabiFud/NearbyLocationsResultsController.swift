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
    func establishmentRemovedAtIndex(index: Int)
    func controllerUpdated()
}

class NearbyLocationsResultsController {
    
    //Subscription Variables
    var subscriptionID = "subscription_id"
    var subscribed = false
    
   
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
    
    //subscription function
    
    func subscribe() {
        //1
        if subscribed {
            return
        }
        //2 See options in step 3
        
        //3
        let subscription = CKSubscription(recordType: RecordType, predicate: predicate!, options:  [.FiresOnRecordCreation, .FiresOnRecordUpdate, .FiresOnRecordDeletion])
        
        //4
        subscription.notificationInfo = CKNotificationInfo()
        subscription.notificationInfo?.alertBody = "Test" //added test
        
        //5
        db.saveSubscription(subscription) { subscription, error in
            if (error != nil) {
                print("error subscribing: \(error)")
            } else {
                self.subscribed = true
                self.listenForBecomeActive()
                print("SUBSCRIBED")
            }
        }
    }
    
    //This is just a convenience method to determine if the item passed into it is already stored in the array of establishments. After all, you can’t remove an object that doesn’t exist.
    func itemMatching(recordID: CKRecordID) -> (item: Establishment!, index: Int) {
        var index = NSNotFound
        var e: Establishment!
        for (idx, value) in results.enumerate() {
            if value.record.recordID == recordID {
                index = idx
                e = value
                break
            }
        }
        return (e, index: index)
    }
    
    func remove(recordID: CKRecordID) {
        dispatch_async(dispatch_get_main_queue()) {
            //1
            var (e, index) = self.itemMatching(recordID)
            //2
            if index == NSNotFound {
                return
            }
            self.delegate.willBeginUpdating()
            //3
            self.results.removeAtIndex(index)
            self.delegate.establishmentRemovedAtIndex(index)
            self.delegate.didEndUpdating(nil)
        }
    }
    
    
    func fetchAndUpdateOrAdd(recordID: CKRecordID) {
        db.fetchRecordWithID(recordID) { record, error in
            if error == nil {
                var (e, index) = self.itemMatching(recordID)
                if index == NSNotFound {
                    e = Establishment(record: record!, database: self.db)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.delegate.willBeginUpdating()
                        self.results.append(e)
                        self.delegate.establishmentAdd(e, index: self.results.count-1)
                        self.delegate.didEndUpdating(nil)
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.delegate.willBeginUpdating()
                        e.record = record
                        self.delegate.establishmentUpdated(e, index: index)
                        self.delegate.didEndUpdating(nil)
                    }
                }
            }
            }
    }
    
    
    func handleNotification(note: CKQueryNotification) {
        let recordID = note.recordID
        switch note.queryNotificationReason {
        case .RecordDeleted:
            remove(note.recordID!)
        case .RecordCreated:
            fetchAndUpdateOrAdd(note.recordID!)
        case .RecordUpdated:
            fetchAndUpdateOrAdd(note.recordID!)
        }
        markNotificationAsRead([note.notificationID!])
    }
    
    func markNotificationAsRead(notes: [CKNotificationID]) {
        let markOp = CKMarkNotificationsReadOperation(notificationIDsToMarkRead: notes)
        CKContainer.defaultContainer().addOperation(markOp)
    }
    
    
    
    func getOustandingNotifications() {
        //1
        let op = CKFetchNotificationChangesOperation(previousServerChangeToken: nil)
        //2 
        op.notificationChangedBlock = {
            notification in
            if let ckNotification = notification as? CKQueryNotification {
                self.handleNotification(ckNotification)
            }
        }
        
        op.fetchNotificationChangesCompletionBlock = {
            serverChangeToken, error in
            //3
            if error != nil {
                print("error fetching notifications \(error)")
            }
        }
        //4 
        CKContainer.defaultContainer().addOperation(op)
        
    }
    
    func listenForBecomeActive() {
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
            self.getOustandingNotifications()
        }
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
        queryOp.desiredKeys = ["Name", "Location", "HealthyOption", "KidsMenu"]
        
        sendOperation(queryOp)
        print("NearbyLocationsResultsController Start method called")
        subscribe()
        getOustandingNotifications()
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
        print("Send Operation Begins")
        //1
        queryOp.queryCompletionBlock = {
            cursor, error in
            
            if isRetryableCkError(error) {
                let userInfo: NSDictionary = (error?.userInfo)!
                //2
                if let retryAfter = userInfo[CKErrorRetryAfterKey] as? NSNumber {
                    let delay = retryAfter.doubleValue * Double(NSEC_PER_SEC)
                    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                    //3
                    dispatch_after(time, dispatch_get_main_queue()) {
                        self.sendOperation(queryOp)
                    }
                    return
                }
            }
            //2
            self.queryCompleted(cursor, error: error)
            print("error: \(error)")
            if (cursor != nil) {
                //3
                self.fetchNextResults(cursor!)
                print("Cursor: \(cursor)")
            } else {
                //4
                self.inProgress = false
                self.persist()
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
   
    //1 
    func cachePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
            // let path = paths[0].stringByAppendingPathComponent("establishments.cache")
        let path = paths[0].stringByAppendingString("establishments.cache")
        return path
    }
    
    func persist() {
        let data = NSMutableData()
        //2
        let archiver = NSKeyedArchiver(forWritingWithMutableData: data)
        //3
        archiver.encodeRootObject(results)
        archiver.finishEncoding()
        //4
        data.writeToFile(cachePath(), atomically: true)
        
    }
    
    func loadCache() {
        let path = cachePath()
        //1 
        if let data = NSData(contentsOfFile: path) where data.length > 0 {
            let decoder = NSKeyedUnarchiver(forReadingWithData: data)
            //2
            let object: AnyObject! = decoder.decodeObject()
            if object != nil {
                //3
                self.results = object as! [Establishment]
                dispatch_async(dispatch_get_main_queue()) {
                    //4 
                    self.delegate.controllerUpdated()
                }
            }
            
        }
    }
    
}

func isRetryableCkError(error:NSError?) -> Bool {
    var isRetryable = false
    //1 
    if let err = error {
        //2
        let isErrorDomain = err.domain == CKErrorDomain
        let errorCode: Int = err.code
        //3
        let isUnavailable = errorCode == CKErrorCode.ServiceUnavailable.rawValue
        let isRateLimited = errorCode == CKErrorCode.RequestRateLimited.rawValue
        let errorCodeIsRetryable = isUnavailable || isRateLimited
        isRetryable = error != nil && isErrorDomain && errorCodeIsRetryable
    }
    return isRetryable
}
