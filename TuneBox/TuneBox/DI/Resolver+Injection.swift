//
//  Resolver+Injection.swift
//  TuneBox
//
//  Created by Nintendo on 07.05.2026.
//

import Moya
import Resolver

extension Resolver: @retroactive ResolverRegistering {

    public static func registerAllServices() {
        self.registerNetworkService()
        self.registerStorageService()
    }

    private static func registerNetworkService() {
        self.register {
            MoyaProvider<TuneBoxRouter>()
        }

        self.register {
            let provider = self.resolve(MoyaProvider<TuneBoxRouter>.self)

            return NetworkService(provider: provider) as NetworkServicing
        }
        .scope(.application)
    }

    private static func registerStorageService() {
        self.register {
            StorageService() as StorageServicing
        }
        .scope(.application)
    }

}
