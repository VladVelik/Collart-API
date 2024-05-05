//
//  OTPService.swift
//
//
//  Created by Vladislav Sosin on 05.05.2024.
//

import Vapor

class OTPService {
    private let request: Request
    private let expirationTime: TimeInterval
    private var otps: [String: (String, Date)] = [:]

    init(request: Request, expirationTime: TimeInterval = 300) {
        self.request = request
        self.expirationTime = expirationTime
    }

    func generateOTP(for email: String) -> String {
        let otp = String((0..<6).map { _ in "0123456789".randomElement()! })
        let expirationDate = Date().addingTimeInterval(expirationTime)
        
        otps[email] = (otp, expirationDate)
        
        return otp
    }

    func verifyOTP(for email: String, otp: String) -> Bool {
        guard let (storedOtp, expirationDate) = otps[email], expirationDate > Date() else {
            return false
        }
        return storedOtp == otp
    }

    func sendOTPEmail(to email: String, otp: String) throws {
        let emailContent = """
        Hello,

        Your one-time password for registration: \(otp)

        This code is valid for 5 minutes.

        Best regards,
        Collart
        """
    }
}
