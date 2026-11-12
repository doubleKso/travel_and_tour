// Port of lib/features/member/di/member_module.dart
import Foundation

extension AppContainer {
    /// `memberRemoteServiceProvider`.
    var memberRemoteService: MemberRemoteService {
        provide { MemberRemoteService(functions) }
    }
}
