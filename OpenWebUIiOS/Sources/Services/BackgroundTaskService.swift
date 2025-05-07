import Foundation
import UIKit
import BackgroundTasks
import UserNotifications

/// Service for managing long-running background tasks such as AI model responses
final class BackgroundTaskService {
    static let shared = BackgroundTaskService()
    
    // Task identifiers
    private let messageProcessingTaskID = "com.openwebui.ios.messageProcessing"
    private let messageCompletionFetchID = "com.openwebui.ios.messageCompletion"
    
    // Storage keys for UserDefaults
    private let pendingMessagesKey = "pendingBackgroundMessages"
    private let partialResponseKeyPrefix = "partialResponse_"
    private let completedMessagesCountKey = "completedMessageCount"
    
    // Status tracking
    @Published private(set) var isBackgroundTaskRunning = false
    @Published private(set) var hasPendingRecovery = false
    
    // Power state monitoring
    private let powerMonitor = PowerMonitor.shared
    
    private init() {
        registerBackgroundTasks()
        
        // Check if we need recovery immediately
        checkPendingRecovery()
    }
    
    // MARK: - Task Registration
    
    /// Register background task types with the system
    private func registerBackgroundTasks() {
        // Register for message processing (long-running task)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: messageProcessingTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleProcessingTask(task as! BGProcessingTask)
        }
        
        // Register for message completion fetch (shorter check)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: messageCompletionFetchID,
            using: nil
        ) { [weak self] task in
            self?.handleFetchTask(task as! BGAppRefreshTask)
        }
        
        print("Background tasks registered for message processing")
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule background processing task
    func scheduleBackgroundProcessing() {
        // Only schedule if there are pending messages
        guard !getPendingMessageIDs().isEmpty else { return }
        
        let request = BGProcessingTaskRequest(identifier: messageProcessingTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Use earliest begin date to prioritize based on battery state
        if powerMonitor.batteryState == .charging {
            // Start sooner if charging
            request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        } else {
            // Delay if on battery
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background processing task scheduled")
        } catch {
            print("Could not schedule background processing: \(error)")
        }
    }
    
    /// Schedule background fetch for completion check
    func scheduleBackgroundFetch() {
        let request = BGAppRefreshTaskRequest(identifier: messageCompletionFetchID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // 10 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background fetch task scheduled")
        } catch {
            print("Could not schedule background fetch: \(error)")
        }
    }
    
    // MARK: - Task Handlers
    
    /// Handle long-running response generation
    private func handleProcessingTask(_ task: BGProcessingTask) {
        print("Starting background processing task")
        isBackgroundTaskRunning = true
        
        // Schedule another task to ensure we have continuation if needed
        scheduleBackgroundProcessing()
        
        // Get pending message IDs from UserDefaults
        let pendingIDs = getPendingMessageIDs()
        guard !pendingIDs.isEmpty else {
            task.setTaskCompleted(success: true)
            isBackgroundTaskRunning = false
            return
        }
        
        // Set up task expiration handler
        task.expirationHandler = { [weak self] in
            // Handle task expiration - save progress
            print("Background task expired before completion")
            self?.isBackgroundTaskRunning = false
        }
        
        // Process the messages
        processMessages(pendingIDs) { [weak self] completedIDs, remainingIDs in
            guard let self = self else { return }
            
            // Save remaining messages as still pending
            self.savePendingMessages(remainingIDs)
            
            // If we completed messages, increment the count for notification
            if !completedIDs.isEmpty {
                self.incrementCompletedMessageCount(by: completedIDs.count)
                
                // Schedule notification if we completed all messages
                if remainingIDs.isEmpty {
                    self.scheduleCompletionNotification(count: completedIDs.count)
                }
            }
            
            // Schedule another task if there are still pending messages
            if !remainingIDs.isEmpty {
                self.scheduleBackgroundProcessing()
            }
            
            // Mark task as completed
            task.setTaskCompleted(success: true)
            self.isBackgroundTaskRunning = false
            print("Background processing task completed with \(completedIDs.count) messages done, \(remainingIDs.count) remaining")
        }
    }
    
    /// Handle shorter check for completed messages
    private func handleFetchTask(_ task: BGAppRefreshTask) {
        // Schedule another fetch for later
        scheduleBackgroundFetch()
        
        // Set expiration handler
        task.expirationHandler = {
            // Clean up any pending operations
            print("Background fetch task expired")
        }
        
        // Check if there are completed or pending messages
        let pendingCount = getPendingMessageIDs().count
        
        if pendingCount > 0 {
            // Schedule a processing task if we have pending messages
            scheduleBackgroundProcessing()
        } else {
            // Check if there are completed messages to notify about
            let completedCount = getCompletedMessageCount()
            if completedCount > 0 {
                scheduleCompletionNotification(count: completedCount)
                clearCompletedMessageCount()
            }
        }
        
        // Mark as completed
        task.setTaskCompleted(success: true)
        print("Background fetch task completed")
    }
    
    // MARK: - Message Processing
    
    /// Process messages in the background
    private func processMessages(_ messageIDs: [String], completion: @escaping ([String], [String]) -> Void) {
        // In a real implementation, this would connect to the appropriate service
        // and continue processing the messages in the background.
        // For now, we'll simulate it with a delay.
        
        // Placeholder for completed IDs and remaining IDs
        var completedIDs: [String] = []
        var remainingIDs = messageIDs
        
        // Simulate processing with a delay
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
            // Pretend we completed half the messages
            let halfCount = messageIDs.count / 2
            if halfCount > 0 {
                completedIDs = Array(messageIDs.prefix(halfCount))
                remainingIDs = Array(messageIDs.dropFirst(halfCount))
            } else if !messageIDs.isEmpty {
                completedIDs = [messageIDs[0]]
                remainingIDs = Array(messageIDs.dropFirst())
            }
            
            completion(completedIDs, remainingIDs)
        }
    }
    
    // MARK: - Public API
    
    /// Add a new message to pending list for background processing
    func addPendingMessage(_ messageID: String, conversationID: String) {
        var pendingIDs = getPendingMessageIDs()
        let combinedID = "\(conversationID):\(messageID)"
        
        if !pendingIDs.contains(combinedID) {
            pendingIDs.append(combinedID)
            savePendingMessages(pendingIDs)
            
            print("Added message \(messageID) to pending background processing")
            
            // Update recovery status
            hasPendingRecovery = true
            
            // Schedule background processing
            scheduleBackgroundProcessing()
        }
    }
    
    /// Save partial response to cache
    func savePartialResponse(messageID: String, content: String) {
        UserDefaults.standard.set(content, forKey: "\(partialResponseKeyPrefix)\(messageID)")
    }
    
    /// Clear partial response from cache
    func clearPartialResponse(for messageID: String) {
        UserDefaults.standard.removeObject(forKey: "\(partialResponseKeyPrefix)\(messageID)")
    }
    
    /// Handle reconnection and partial response recovery
    func recoverPartialResponses(completion: @escaping ([String: String]) -> Void) {
        let pendingIDs = getPendingMessageIDs()
        var partialResponses: [String: String] = [:]
        
        for idPair in pendingIDs {
            let components = idPair.split(separator: ":")
            if components.count == 2 {
                let messageID = String(components[1])
                
                // Get partial response from cache
                if let partialResponse = getPartialResponse(for: messageID) {
                    partialResponses[messageID] = partialResponse
                }
            }
        }
        
        // Clear recovery flag if no partials
        hasPendingRecovery = !partialResponses.isEmpty
        
        completion(partialResponses)
    }
    
    /// Request notification permissions
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if we have pending messages that need recovery
    private func checkPendingRecovery() {
        let pendingIDs = getPendingMessageIDs()
        hasPendingRecovery = !pendingIDs.isEmpty
    }
    
    /// Get pending message IDs
    private func getPendingMessageIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: pendingMessagesKey) ?? []
    }
    
    /// Save pending message IDs
    private func savePendingMessages(_ messageIDs: [String]) {
        UserDefaults.standard.set(messageIDs, forKey: pendingMessagesKey)
        
        // Update recovery status
        hasPendingRecovery = !messageIDs.isEmpty
    }
    
    /// Clear all pending messages
    func clearAllPendingMessages() {
        savePendingMessages([])
    }
    
    /// Get partial response from cache
    private func getPartialResponse(for messageID: String) -> String? {
        UserDefaults.standard.string(forKey: "\(partialResponseKeyPrefix)\(messageID)")
    }
    
    /// Track completed messages for notification
    private func incrementCompletedMessageCount(by count: Int = 1) {
        let currentCount = getCompletedMessageCount()
        UserDefaults.standard.set(currentCount + count, forKey: completedMessagesCountKey)
    }
    
    private func getCompletedMessageCount() -> Int {
        UserDefaults.standard.integer(forKey: completedMessagesCountKey)
    }
    
    private func clearCompletedMessageCount() {
        UserDefaults.standard.removeObject(forKey: completedMessagesCountKey)
    }
    
    /// Schedule local notification for message completion
    private func scheduleCompletionNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Message Generation Complete"
        content.body = count == 1 ? 
            "Your AI response is ready to view" : 
            "\(count) AI responses are ready to view"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}