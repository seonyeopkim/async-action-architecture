@testable import AsyncActionArchitecture
import XCTest

final class PassthroughTests: XCTestCase {
    func testUIntOverflowOperator() {
        // given
        var wrapper = Passthrough(wrappedValue: Int.zero)
        
        // when
        wrapper.version = .max
        wrapper.wrappedValue = .zero
        
        // then
        XCTAssertEqual(wrapper.version, .zero)
    }
    
    func testWrappersEqual() {
        // given
        var wrapperA = Passthrough(wrappedValue: Int.zero)
        var wrapperB = Passthrough(wrappedValue: Int.zero)
        
        // when
        wrapperA.version = .min
        wrapperB.version = .max
        wrapperA.wrappedValue = .zero
        wrapperB.wrappedValue = .zero
        
        // then
        XCTAssertEqual(wrapperA, wrapperB)
    }
    
    func testWrappersNotEqual() {
        // given
        var wrapperA = Passthrough(wrappedValue: Int.zero)
        var wrapperB = Passthrough(wrappedValue: Int.zero)
        
        // when
        wrapperA.version = .zero
        wrapperB.version = .zero
        wrapperA.wrappedValue = .min
        wrapperB.wrappedValue = .max
        
        // then
        XCTAssertNotEqual(wrapperA, wrapperB)
    }
}
