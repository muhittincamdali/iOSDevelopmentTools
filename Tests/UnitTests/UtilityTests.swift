import XCTest
import Quick
import Nimble
@testable import UtilityTools

class UtilityTests: QuickSpec {
    
    override func spec() {
        
        describe("UtilityExtensions") {
            
            context("String Extensions") {
                
                it("should validate email format") {
                    let validEmail = "test@example.com"
                    let invalidEmail = "invalid-email"
                    
                    expect(validEmail.isValidEmail).to(beTrue())
                    expect(invalidEmail.isValidEmail).to(beFalse())
                }
                
                it("should format phone number") {
                    let phoneNumber = "1234567890"
                    let formatted = phoneNumber.formattedPhoneNumber()
                    
                    expect(formatted).to(equal("(123) 456-7890"))
                }
                
                it("should generate random string") {
                    let randomString = String.random(length: 10)
                    
                    expect(randomString.count).to(equal(10))
                    expect(randomString).toNot(beEmpty())
                }
            }
            
            context("Date Extensions") {
                
                it("should format date to string") {
                    let date = Date()
                    let formatted = date.formattedString()
                    
                    expect(formatted).toNot(beEmpty())
                    expect(formatted).to(contain("202"))
                }
                
                it("should calculate age") {
                    let birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
                    let age = birthDate.age()
                    
                    expect(age).to(equal(25))
                }
                
                it("should check if date is today") {
                    let today = Date()
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                    
                    expect(today.isToday).to(beTrue())
                    expect(yesterday.isToday).to(beFalse())
                }
            }
            
            context("Array Extensions") {
                
                it("should safely access array elements") {
                    let array = [1, 2, 3, 4, 5]
                    
                    expect(array[safe: 2]).to(equal(3))
                    expect(array[safe: 10]).to(beNil())
                }
                
                it("should remove duplicates") {
                    let array = [1, 2, 2, 3, 3, 4]
                    let unique = array.removingDuplicates()
                    
                    expect(unique).to(equal([1, 2, 3, 4]))
                }
                
                it("should chunk array") {
                    let array = [1, 2, 3, 4, 5, 6]
                    let chunks = array.chunked(into: 2)
                    
                    expect(chunks.count).to(equal(3))
                    expect(chunks[0]).to(equal([1, 2]))
                }
            }
            
            context("Dictionary Extensions") {
                
                it("should merge dictionaries") {
                    let dict1 = ["a": 1, "b": 2]
                    let dict2 = ["c": 3, "d": 4]
                    let merged = dict1.merging(dict2)
                    
                    expect(merged.count).to(equal(4))
                    expect(merged["a"]).to(equal(1))
                    expect(merged["c"]).to(equal(3))
                }
                
                it("should filter dictionary") {
                    let dict = ["a": 1, "b": 2, "c": 3, "d": 4]
                    let filtered = dict.filter { $0.value % 2 == 0 }
                    
                    expect(filtered.count).to(equal(2))
                    expect(filtered["b"]).to(equal(2))
                    expect(filtered["d"]).to(equal(4))
                }
            }
            
            context("Color Extensions") {
                
                it("should create color from hex") {
                    let color = UIColor(hex: "#FF0000")
                    
                    expect(color).toNot(beNil())
                }
                
                it("should convert color to hex") {
                    let color = UIColor.red
                    let hex = color.toHex()
                    
                    expect(hex).toNot(beEmpty())
                }
            }
            
            context("View Extensions") {
                
                it("should add corner radius") {
                    let view = UIView()
                    view.addCornerRadius(10)
                    
                    expect(view.layer.cornerRadius).to(equal(10))
                }
                
                it("should add shadow") {
                    let view = UIView()
                    view.addShadow()
                    
                    expect(view.layer.shadowOpacity).to(beGreaterThan(0))
                }
            }
        }
    }
}
