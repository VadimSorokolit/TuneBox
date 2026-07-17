//
//  Resolver+Injection.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 07.05.2026.
//

import Moya
import Resolver

@MainActor
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
            MainActor.assumeIsolated {
                do {
                    return try PersistenceService() as PersistenceServicing
                } catch {
                    fatalError("Failed to create PersistenceService: \(error)")
                }
            }
        }
        .scope(.application)
    }

    private static func registerViewModels() {
        self.register {
            MainActor.assumeIsolated {
                TransferViewModel(
                    networkService: self.resolve(NetworkServicing.self),
                    storageService: self.resolve(FileManagerServicing.self)
                ) as TransferManaging
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                DownloadsViewModel()
                as DownloadsPresenting
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                ImportViewModelV1()
                as ImportManagingV1
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                ImportViewModel()
                as ImportManaging
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                PlayerViewModel()
                as PlayerManaging
            }
        }
    }

}
