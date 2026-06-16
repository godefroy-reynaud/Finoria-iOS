//
//  CloudKitService.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/03/2026.
//

import Foundation
import CloudKit
import UIKit
import UserNotifications
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

	// MARK: - Subscription Push Notifications
	
	/// Souscrit aux notifications d'annonces via CKQuerySubscription sur la base **publique**.
	///
	/// Appelé à chaque lancement — CloudKit écrase la subscription existante si même ID,
	/// ce qui garantit qu'elle est toujours enregistrée (pas de désynchronisation UserDefaults).
	/// Quand un nouveau record **Announcements** est créé (depuis le CloudKit Dashboard),
	/// **tous** les utilisateurs ayant l'app installée reçoivent une notification push.
	///
	/// ### Configuration requise dans le CloudKit Dashboard :
	/// 1. Aller sur https://icloud.developer.apple.com
	/// 2. Sélectionner le container `iCloud.com.godefroyinformatique.GDF-app`
	/// 3. Dans **Schema → Record Types**, créer le type **Announcements** avec :
	///    - `title` (String) — titre de la notification
	///    - `body` (String) — contenu de la notification
	/// 4. Pour envoyer une notif : créer un nouveau record dans **Data → Public Database → Announcements**
	/// - Returns: `nil` si la subscription a été enregistrée, sinon un message d'erreur lisible.
	@discardableResult
	static func subscribeToAnnouncements() async -> String? {
		let predicate = NSPredicate(value: true)
		let subscription = CKQuerySubscription(
			recordType: "Announcements",
			predicate: predicate,
			subscriptionID: "all-announcements",
			options: [.firesOnRecordCreation]
		)

		let notificationInfo = CKSubscription.NotificationInfo()
		notificationInfo.titleLocalizationKey = "CK_ANNOUNCEMENT_TITLE"
		notificationInfo.titleLocalizationArgs = ["title"]
		notificationInfo.alertLocalizationKey = "CK_ANNOUNCEMENT_BODY"
		notificationInfo.alertLocalizationArgs = ["body"]
		notificationInfo.soundName = "default"
		notificationInfo.shouldBadge = true
		subscription.notificationInfo = notificationInfo

		do {
			_ = try await container.publicCloudDatabase.save(subscription)
			logger.info("CloudKit: subscription annonces enregistrée ✓")
			return nil
		} catch {
			let ckError = error as? CKError
			let code = ckError.map { "CKError \($0.code.rawValue)" } ?? "Erreur"
			logger.error("CloudKit: erreur subscription annonces (\(code)): \(error.localizedDescription)")
			return "\(code) — \(error.localizedDescription)"
		}
	}

	// ════════════════════════════════════════════════════════════════════════
	// ⚠️ DEBUG — À SUPPRIMER UNE FOIS LES TESTS NOTIFS TERMINÉS
	// ════════════════════════════════════════════════════════════════════════
	// À retirer en fin de tests :
	//  1. Tout ce bloc « Diagnostic Push » ci-dessous (jusqu'au prochain séparateur)
	//  2. Les imports `import UIKit` et `import UserNotifications` en haut de ce fichier
	//     (ajoutés uniquement pour ce diagnostic)
	//  3. Dans HomeTabView.swift : les @State showPushDiagnostic / pushDiagnosticText,
	//     le .simultaneousGesture(LongPressGesture…) sur le bouton d'import,
	//     l'.alert("Diagnostic notifications"…) et la fonction runPushDiagnostic()
	// ════════════════════════════════════════════════════════════════════════

	// MARK: - Diagnostic Push (à afficher dans l'app pour debugging TestFlight)

	/// Récupère toutes les subscriptions de la base publique pour le compte iCloud courant.
	// WHY: pas d'API async stable pour fetchAllSubscriptions — on enveloppe la version
	// à completion handler (stable depuis iOS 8) pour éviter une erreur de compilation.
	private static func fetchAllPublicSubscriptions() async throws -> [CKSubscription] {
		try await withCheckedThrowingContinuation { continuation in
			container.publicCloudDatabase.fetchAllSubscriptions { subscriptions, error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: subscriptions ?? [])
				}
			}
		}
	}

	/// Diagnostic complet du système de notifications push « annonces ».
	///
	/// Vérifie les 4 conditions nécessaires pour recevoir une notif depuis le Dashboard :
	/// compte iCloud connecté, permission notifications accordée, inscription APNs,
	/// et présence de la subscription `all-announcements`. Si la subscription est
	/// absente, tente de la recréer immédiatement.
	/// - Returns: Un rapport lisible à afficher dans une alerte.
	static func diagnosePush() async -> String {
		var lines: [String] = []

		// 1. Compte iCloud
		let status = await checkAccountStatus()
		lines.append("iCloud : " + (status.isAvailable ? "✅ connecté" : "❌ \(status.alertTitle)"))

		// 2. Permission notifications
		let settings = await UNUserNotificationCenter.current().notificationSettings()
		switch settings.authorizationStatus {
		case .authorized, .provisional, .ephemeral:
			lines.append("Notifications : ✅ autorisées")
		case .denied:
			lines.append("Notifications : ❌ refusées\n→ Réglages › Finoria › Notifications, puis tout activer")
		case .notDetermined:
			lines.append("Notifications : ⏳ jamais demandées (relance l'app)")
		@unknown default:
			lines.append("Notifications : ❓ statut inconnu")
		}

		// 3. Inscription APNs (requise pour que CloudKit pousse les notifs)
		let registered = await MainActor.run { UIApplication.shared.isRegisteredForRemoteNotifications }
		lines.append("APNs : " + (registered ? "✅ enregistré" : "❌ non enregistré (vérifie la capacité Push Notifications)"))

		// 4. Subscription CloudKit
		do {
			let subs = try await fetchAllPublicSubscriptions()
			if subs.contains(where: { $0.subscriptionID == "all-announcements" }) {
				lines.append("Subscription : ✅ active (all-announcements)")
			} else {
				// Tente de la créer ET capture l'erreur exacte pour l'afficher
				if let err = await subscribeToAnnouncements() {
					lines.append("Subscription : ❌ échec création\n\(err)")
				} else {
					lines.append("Subscription : ✅ créée à l'instant — relance le diagnostic pour confirmer")
				}
			}
		} catch {
			lines.append("Subscription : ❌ lecture impossible\n\(error.localizedDescription)")
		}

		return lines.joined(separator: "\n\n")
	}
	// ════════════════════════════════════════════════════════════════════════
	// ⚠️ FIN DU BLOC DEBUG À SUPPRIMER
	// ════════════════════════════════════════════════════════════════════════

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
