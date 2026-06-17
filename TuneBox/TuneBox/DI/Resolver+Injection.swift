//
//  Resolver+Injection.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Moya
import Resolver

extension Resolver: @retroactive ResolverRegistering {

    public static func registerAllServices() {
        self.registerNetworkService()
        self.registerStorageService()
        self.registerPersistenceService()
        self.registerViewModels()
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
            FileManagerService() as FileManagerServicing
        }
        .scope(.application)
    }

    private static func registerPersistenceService() {
        self.register {
            do {
                return try PersistenceService() as PersistenceServicing
            } catch {
                fatalError("Failed to create PersistenceService: \(error)")
            }
        }
    }

    private static func registerViewModels() {
        self.register {
            TransferViewModel(
                networkService: self.resolve(NetworkServicing.self),
                persistenceService: self.resolve(PersistenceServicing.self),
                storageService: self.resolve(FileManagerServicing.self)
            ) as TransferManaging
        }
        .scope(.application)

        self.register {
            DownloadsViewModel()
            as DownloadsPresenting
        }
        .scope(.application)

        self.register {
            PlayerViewModel()
            as PlayerManaging
        }
    }

}
