import XCTest
import Quick
import Nimble
@testable import AnalyticsTools

class AnalyticsManagerTests: QuickSpec {
    
    override func spec() {
        
        describe("AnalyticsManager") {
            
            var analyticsManager: AnalyticsManager!
            
            beforeEach {
                analyticsManager = AnalyticsManager.shared
            }
            
            context("Initialization") {
                
                it("should initialize successfully") {
                    expect(analyticsManager).toNot(beNil())
                }
                
                it("should have default configuration") {
                    expect(analyticsManager.isEnabled).to(beTrue())
                    expect(analyticsManager.isDebugMode).to(beFalse())
                }
            }
            
            context("Event Tracking") {
                
                it("should track custom events") {
                    let eventName = "user_login"
                    let parameters = ["user_id": "123", "method": "email"]
                    
                    analyticsManager.trackEvent(eventName, parameters: parameters)
                    
                    // Verify event was tracked
                    expect(analyticsManager.eventsCount).to(beGreaterThan(0))
                }
                
                it("should track screen views") {
                    let screenName = "HomeScreen"
                    
                    analyticsManager.trackScreenView(screenName)
                    
                    expect(analyticsManager.screenViewsCount).to(beGreaterThan(0))
                }
                
                it("should track user actions") {
                    let action = "button_tap"
                    let element = "login_button"
                    
                    analyticsManager.trackUserAction(action, element: element)
                    
                    expect(analyticsManager.userActionsCount).to(beGreaterThan(0))
                }
            }
            
            context("User Properties") {
                
                it("should set user properties") {
                    let properties = [
                        "user_id": "123",
                        "user_type": "premium",
                        "registration_date": "2024-01-01"
                    ]
                    
                    analyticsManager.setUserProperties(properties)
                    
                    expect(analyticsManager.userProperties).to(equal(properties))
                }
                
                it("should set user ID") {
                    let userId = "user_123"
                    
                    analyticsManager.setUserId(userId)
                    
                    expect(analyticsManager.userId).to(equal(userId))
                }
            }
            
            context("Performance Tracking") {
                
                it("should track performance metrics") {
                    let metricName = "api_response_time"
                    let value = 150.0
                    
                    analyticsManager.trackPerformance(metricName, value: value)
                    
                    expect(analyticsManager.performanceMetricsCount).to(beGreaterThan(0))
                }
                
                it("should track memory usage") {
                    analyticsManager.trackMemoryUsage()
                    
                    expect(analyticsManager.memoryUsageCount).to(beGreaterThan(0))
                }
                
                it("should track battery usage") {
                    analyticsManager.trackBatteryUsage()
                    
                    expect(analyticsManager.batteryUsageCount).to(beGreaterThan(0))
                }
            }
            
            context("Error Tracking") {
                
                it("should track errors") {
                    let error = NSError(domain: "TestDomain", code: 100, userInfo: nil)
                    
                    analyticsManager.trackError(error)
                    
                    expect(analyticsManager.errorsCount).to(beGreaterThan(0))
                }
                
                it("should track crashes") {
                    let crashInfo = ["reason": "memory_pressure", "stack_trace": "test"]
                    
                    analyticsManager.trackCrash(crashInfo)
                    
                    expect(analyticsManager.crashesCount).to(beGreaterThan(0))
                }
            }
            
            context("Configuration") {
                
                it("should enable/disable analytics") {
                    analyticsManager.setEnabled(false)
                    expect(analyticsManager.isEnabled).to(beFalse())
                    
                    analyticsManager.setEnabled(true)
                    expect(analyticsManager.isEnabled).to(beTrue())
                }
                
                it("should set debug mode") {
                    analyticsManager.setDebugMode(true)
                    expect(analyticsManager.isDebugMode).to(beTrue())
                }
                
                it("should set batch size") {
                    let batchSize = 50
                    analyticsManager.setBatchSize(batchSize)
                    
                    expect(analyticsManager.batchSize).to(equal(batchSize))
                }
            }
            
            context("Data Management") {
                
                it("should flush data") {
                    analyticsManager.trackEvent("test_event")
                    analyticsManager.flush()
                    
                    expect(analyticsManager.eventsCount).to(equal(0))
                }
                
                it("should clear all data") {
                    analyticsManager.trackEvent("test_event")
                    analyticsManager.clearAllData()
                    
                    expect(analyticsManager.eventsCount).to(equal(0))
                    expect(analyticsManager.userProperties).to(beEmpty())
                }
            }
        }
    }
}
