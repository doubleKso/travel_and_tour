// Port of lib/features/visa/di/visa_module.dart

import Foundation

extension AppContainer {
    /// `visaRemoteServiceProvider`.
    var visaRemoteService: VisaRemoteService {
        provide { VisaRemoteService(functions) }
    }
}
