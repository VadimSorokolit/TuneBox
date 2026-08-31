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
        self.registerJamendoService()
        self.registerCoverService()
        self.registerStorageService()
        self.registerPersistenceService()
        self.registerPurchaseServices()
        self.registerViewModels()
    }

    private static func registerPurchaseServices() {
        self.register {
            MainActor.assumeIsolated {
                EntitlementService() as EntitlementServicing
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                PurchaseService(
                    entitlementService: self.resolve(EntitlementServicing.self)
                ) as PurchaseServicing
            }
        }
        .scope(.application)
    }

    private static func registerJamendoService() {
        self.register {
            MoyaProvider<JamendoRouter>()
        }

        self.register {
            let provider = self.resolve(MoyaProvider<JamendoRouter>.self)

            return JamendoService(provider: provider) as JamendoServicing
        }
        .scope(.application)
    }

    private static func registerCoverService() {
        self.register {
            MoyaProvider<CoverRouter>()
        }

        self.register {
            let provider = self.resolve(MoyaProvider<CoverRouter>.self)

            return CoverService(provider: provider) as CoverServicing
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
                    jamendoService: self.resolve(JamendoServicing.self),
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
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                CoverViewModel()
                as CoverManaging
            }
        }
        .scope(.application)

        self.register {
            MainActor.assumeIsolated {
                RootTabsViewModel()
                as RootTabsManaging
            }
        }
        .scope(.application)
    }

}
