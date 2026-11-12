import XCTest
@testable import EpicWorld

/// Ports packages/app_network/test/api_exception_test.dart and
/// failure_mapper_test.dart.
final class ApiExceptionTests: XCTestCase {
    func testPrefersBackendDetailsMessageOverCallableLabel() {
        let message = ApiException.firebaseFunctionsMessage(
            details: ["code": "EMAIL_ALREADY_EXISTS", "message": "An account already exists for this email address."],
            message: "Sign up failed"
        )
        XCTAssertEqual(message, "An account already exists for this email address.")
    }

    func testFindsNestedMessageInJsonEncodedDetails() {
        let message = ApiException.firebaseFunctionsMessage(
            details: #"{"error":{"message":"The verification code expired."}}"#,
            message: "Verification failed"
        )
        XCTAssertEqual(message, "The verification code expired.")
    }

    func testRemovesFirebaseFunctionsCodePrefixes() {
        XCTAssertEqual(
            ApiException.cleanMessage("[firebase_functions/already-exists] Email is already registered."),
            "Email is already registered."
        )
    }

    func testRemovesExceptionClassPrefixes() {
        XCTAssertEqual(
            ApiException.messageFrom(FormatException("The server response was invalid.")),
            "The server response was invalid."
        )
    }

    func testThrowsOnlyTheMessageFromAFailureEnvelope() {
        XCTAssertThrowsError(try ApiException.callablePayload([
            "success": false,
            "message": "Sign up failed",
            "error": ["message": "That email address is already registered."],
        ], endpoint: "authSignup")) { error in
            XCTAssertEqual((error as? ApiException)?.message, "That email address is already registered.")
        }
    }

    func testPrefersReturnedFailureDetailsOverGenericLabel() {
        XCTAssertThrowsError(try ApiException.callablePayload([
            "ok": false,
            "message": "Sign up failed",
            "details": ["message": "The username has already been taken."],
        ], endpoint: "authSignup")) { error in
            XCTAssertEqual((error as? ApiException)?.message, "The username has already been taken.")
        }
    }

    func testUnwrapsSuccessfulCallableResult() throws {
        let payload = try ApiException.callablePayload(["result": ["ok": true, "value": 42]], endpoint: "exampleCallable")
        XCTAssertEqual(Dart.bool(payload["ok"]), true)
        XCTAssertEqual(Dart.int(payload["value"]), 42)
        XCTAssertEqual(payload.count, 2)
    }

    func testUnwrapsCreatePaymentIntentEnvelope() throws {
        let payload = try ApiException.callablePayload([
            "result": [
                "ok": true,
                "paymentUrl": "https://pay-uat.smarticwork.com/payment?id=123",
                "merchantOrderNo": "EW-QSGD99-1",
            ],
        ], endpoint: "/createPaymentIntent")
        XCTAssertTrue((Dart.str(payload["paymentUrl"]) ?? "").contains("pay-uat.smarticwork.com"))
        XCTAssertEqual(Dart.str(payload["merchantOrderNo"]), "EW-QSGD99-1")
    }

    func testRecognisesBackendWordingForDeadAccessToken() {
        let errors: [Any] = [
            ApiException("Access token expired"),
            StateError("Access token expired"),
            Exception("access token is invalid"),
            ApiException("Session expired. Please sign in again."),
            FunctionsException(code: "unauthenticated", message: "Missing credentials"),
        ]
        for error in errors {
            XCTAssertTrue(ApiException.isSessionExpired(error), "expected \(error) to be an expired session")
        }
    }

    func testLeavesEveryOtherFailureToTheCaller() {
        let errors: [Any?] = [
            nil,
            ApiException("SmartPay did not return a payment link."),
            ApiException("The booking reference no longer exists."),
            StateError("No internet connection."),
            FunctionsException(code: "unavailable", message: "Service is temporarily unavailable"),
        ]
        for error in errors {
            XCTAssertFalse(ApiException.isSessionExpired(error), "expected \(String(describing: error)) not to renew")
        }
    }
}

final class FailureMapperTests: XCTestCase {
    func testUnreachableCallableIsNetworkFailure() {
        for code in ["unavailable", "deadline-exceeded"] {
            XCTAssertEqual(FailureMapper.from(FunctionsException(code: code, message: "x")), .network())
        }
    }

    func testRejectedCallableKeepsBackendWording() {
        let failure = FailureMapper.from(FunctionsException(
            code: "not-found",
            message: "Sign up failed",
            details: ["message": "No account uses that email."]
        ))
        XCTAssertEqual(failure, .server(message: "No account uses that email."))
    }

    func testHttpConnectionProblemIsNetworkFailure() {
        let error = HTTPException(type: .connectionTimeout, message: nil, statusCode: nil, responseData: nil, url: nil)
        XCTAssertEqual(FailureMapper.from(error), .network())
    }

    func testHttpErrorResponseKeepsMessageAndStatus() {
        let error = HTTPException(type: .badResponse, message: "x", statusCode: 422, responseData: ["message": "Email is taken."], url: nil)
        XCTAssertEqual(FailureMapper.from(error), .server(message: "Email is taken.", statusCode: 422))
    }

    func testApiExceptionIsServerFailure() {
        XCTAssertEqual(FailureMapper.from(ApiException("Seats are gone.")), .server(message: "Seats are gone."))
    }

    func testParseErrorsAndOthersLoseTheirPrefixes() {
        XCTAssertEqual(FailureMapper.from(FormatException("Bad payload")), .parsing("Bad payload"))
        XCTAssertEqual(FailureMapper.from(Exception("Oops")), .unexpected("Oops"))
    }

    func testFailurePassesThroughUnchanged() {
        XCTAssertEqual(FailureMapper.from(AppFailure.cache("No session")), .cache("No session"))
    }
}
