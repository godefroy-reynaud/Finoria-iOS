//
//  CloudKitService.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/03/2026.
//

import Foundation
import CloudKit
import os.log

/// Service de diagnostic CloudKit.
///
/// Vérifie que toutes les conditions sont réunies pour que la synchronisation iCloud fonctionne :
/// 1. L'utilisateur est connecté à un compte iCloud
/// 2. Le container CloudKit est accessible
/// 3. Le réseau est disponible
///
/// Utilise l'API officielle Apple `CKContainer.accountStatus()`.
enum CloudKitService {
	
	// MARK: - Logger
	
	private static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.finoria",
		category: "CloudKitService"
	)
	
	/// Container CloudKit de l'application
	private static let container = CKContainer(identifier: "iCloud.com.godefroyinformatique.GDF-app")

	// MARK: - Statut CloudKit
	
	/// Résultat du diagnostic CloudKit
	enum CloudKitStatus {
		/// CloudKit fonctionne correctement
		case available
		/// L'utilisateur n'est pas connecté à iCloud
		case noAccount
		/// Le compte iCloud est restreint (contrôle parental, MDM)
		case restricted
		/// iCloud est temporairement indisponible
		case temporarilyUnavailable
		/// Le compte iCloud a changé (anciennes données potentiellement inaccessibles)
		case couldNotDetermine
		/// Erreur réseau ou autre
		case error(String)
		
		/// Message lisible pour l'utilisateur
		var userMessage: String {
			switch self {
			case .available:
				return "iCloud fonctionne correctement."
			case .noAccount:
				return "Vous n'êtes pas connecté à iCloud. Vos données ne seront pas synchronisées entre vos appareils.\n\nAllez dans Réglages → votre nom → iCloud pour vous connecter."
			case .restricted:
				return "L'accès à iCloud est restreint sur cet appareil (contrôle parental ou gestion d'entreprise). La synchronisation est désactivée."
			case .temporarilyUnavailable:
				return "iCloud est temporairement indisponible. Vos données seront synchronisées automatiquement dès que le service sera rétabli."
			case .couldNotDetermine:
				return "Impossible de vérifier le statut iCloud. Vérifiez votre connexion internet et réessayez."
			case .error(let message):
				return "Erreur de synchronisation iCloud : \(message)"
			}
		}
		
		/// Titre de l'alerte
		var alertTitle: String {
			switch self {
			case .available:
				return "iCloud activé ✅"
			case .noAccount:
				return "iCloud non connecté"
			case .restricted:
				return "iCloud restreint"
			case .temporarilyUnavailable:
				return "iCloud indisponible"
			case .couldNotDetermine:
				return "Vérification impossible"
			case .error:
				return "Erreur iCloud"
			}
		}
		
		/// true si CloudKit est fonctionnel
		var isAvailable: Bool {
			if case .available = self { return true }
			return false
		}
	}
	
	// MARK: - Vérification
	
	/// Vérifie le statut du compte iCloud de l'utilisateur.
	///
	/// Utilise l'API officielle `CKContainer.accountStatus()` recommandée par Apple.
	/// - Returns: Le statut CloudKit avec un message explicite en cas de problème.
	static func checkAccountStatus() async -> CloudKitStatus {
		do {
			let status = try await container.accountStatus()
			
			switch status {
			case .available:
				// Compte iCloud OK — vérifier aussi que le container est accessible
				return await verifyContainerAccess()
				
			case .noAccount:
				logger.warning("CloudKit: pas de compte iCloud")
				return .noAccount
				
			case .restricted:
				logger.warning("CloudKit: compte restreint")
				return .restricted
				
			case .couldNotDetermine:
				logger.warning("CloudKit: statut indéterminé")
				return .couldNotDetermine
				
			case .temporarilyUnavailable:
				logger.warning("CloudKit: temporairement indisponible")
				return .temporarilyUnavailable
				
			@unknown default:
				logger.warning("CloudKit: statut inconnu")
				return .couldNotDetermine
			}
		} catch {
			logger.error("CloudKit: erreur vérification account status: \(error.localizedDescription)")
			return .error(error.localizedDescription)
		}
	}
	
	// MARK: - Vérification du container
	
	/// Vérifie que le container CloudKit est bien accessible en tentant un fetch du userRecordID.
	private static func verifyContainerAccess() async -> CloudKitStatus {
		do {
			let _ = try await container.userRecordID()
			logger.info("CloudKit: container accessible, utilisateur identifié")
			return .available
		} catch {
			let ckError = error as? CKError
			
			if let ckError = ckError {
				switch ckError.code {
				case .networkUnavailable, .networkFailure:
					logger.warning("CloudKit: pas de réseau")
					return .error("Pas de connexion internet. Vérifiez votre Wi-Fi ou données cellulaires.")
					
				case .notAuthenticated:
					logger.warning("CloudKit: pas authentifié")
					return .noAccount
					
				case .quotaExceeded:
					logger.warning("CloudKit: quota dépassé")
					return .error("Votre stockage iCloud est plein. Libérez de l'espace dans Réglages → iCloud → Gérer le stockage.")
					
				case .serviceUnavailable, .requestRateLimited:
					logger.warning("CloudKit: service indisponible")
					return .temporarilyUnavailable
					
				default:
					logger.warning("CloudKit: erreur CK \(ckError.code.rawValue): \(ckError.localizedDescription)")
					return .error(ckError.localizedDescription)
				}
			}
			
			logger.warning("CloudKit: erreur non-CK: \(error.localizedDescription)")
			return .error(error.localizedDescription)
		}
	}
}
