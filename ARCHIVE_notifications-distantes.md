# 📦 ARCHIVE — Notifications push « à distance » (annonces)

> **Statut : ABANDONNÉ / EN PAUSE (juin 2026).**
> Fonctionnalité retirée du code à la demande de l'utilisateur : « trop compliqué pour
> une utilité très limitée ». Ce fichier **n'est pas compilé** (markdown). Il conserve
> tout le code retiré + le savoir durement acquis, pour pouvoir réessayer un jour sans
> repartir de zéro.
>
> ⚠️ Ce qui a été retiré ne concerne **QUE** les notifications d'annonces broadcast.
> La **synchronisation iCloud des données (SwiftData + CloudKit)** est intacte et continue
> de fonctionner : `CloudKitService.checkAccountStatus()`, le container `.automatic`, les
> entitlements iCloud/Push, le background mode `remote-notification` et l'inscription APNs
> dans `Notifications.swift` (utilisés par la synchro) sont **conservés**.

---

## 1. But de la fonctionnalité

Envoyer une notification push à **tous** les utilisateurs de l'app, à tout moment, depuis
le **CloudKit Dashboard** (sans serveur), en créant un record dans la base publique.

Mécanisme : chaque appareil crée une `CKQuerySubscription` sur la base **publique** du
container, type de record `Announcements` (champs `title` + `body`). Quand un record
`Announcements` est créé dans le Dashboard, CloudKit pousse une notif à tous les abonnés.
Le titre/corps viennent des champs du record, injectés via des clés de localisation.

---

## 2. ⚠️ Pièges CloudKit rencontrés (l'essentiel à retenir)

1. **`NSPredicate(value: true)` / `TRUEPREDICATE` est INTERDIT en Production.**
   → `CKError 12` : *« attempting to create a subscription in a production container »*.
   Ça passe en Development mais **jamais** en Production (donc jamais en TestFlight/App Store).
   **Fix : un vrai prédicat sur un champ queryable**, ex. `NSPredicate(format: "title != %@", "")`.
   (Confirmé sur les forums Apple, thread 12276.)

2. **Le champ du prédicat (`title`) doit être marqué QUERYABLE** dans le schéma, et déployé
   en Production, sinon `save(subscription)` échoue. `body` n'a PAS besoin d'être queryable
   (il n'est jamais interrogé, juste affiché). Marquer un champ queryable se fait dans
   **Schema → Indexes** (pas Record Types).

3. **Le schéma Production est append-only (verrouillé).** On ne peut ni supprimer ni modifier
   un type/champ en Production (« invalid attempt to delete a record type which is active in a
   production container » = normal). Toute modif de schéma se fait en **Development** puis se
   pousse via **Deploy Schema Changes**.

4. **Les subscriptions CloudKit sont PAR-UTILISATEUR.** On ne les voit dans le Dashboard
   (onglet Subscriptions) qu'en « Act As iCloud Account » du compte de l'appareil. Ne pas la
   voir ≠ elle n'existe pas.

5. **Environnement : build Xcode = Development, TestFlight/App Store = Production.** Créer les
   records `Announcements` dans le bon environnement, et déployer le schéma en Production.

6. **Localisation :** le contenu dynamique de la notif vient des champs du record via
   `titleLocalizationKey`/`titleLocalizationArgs`. Les clés `CK_ANNOUNCEMENT_TITLE` / `_BODY`
   doivent exister dans `Localizable.strings` (valeur `"%1$@"`). Si la notif affiche la clé
   brute au lieu du texte, déplacer `Localizable.strings` dans `Base.lproj`.

---

## 3. Procédure CloudKit Dashboard (pour réactiver un jour)

1. https://icloud.developer.apple.com → container `iCloud.com.godefroyinformatique.GDF-app`
2. Passer en environnement **Development**.
3. **Schema → Record Types** : créer/vérifier `Announcements` avec `title` (String) + `body` (String).
4. **Schema → Indexes** : ajouter un index **QUERYABLE** sur `title`.
5. **Deploy Schema Changes** → vers Production.
6. Réintégrer le code (section 4), réuploader un build.
7. Vérifier via le diagnostic in-app (section 4.3).
8. Pour envoyer : **Records → Public Database → New Record → `Announcements`** → renseigner
   `title` (obligatoire, sinon le prédicat ne matche pas) + `body` → Save.

---

## 4. Code retiré (à restaurer)

### 4.1 `CloudKitService.swift` — imports + fonction de subscription

Ajouter en haut du fichier (à côté de `import Foundation` / `import CloudKit` / `import os.log`),
**uniquement si le diagnostic 4.3 est aussi restauré** (sinon `UIKit`/`UserNotifications` inutiles) :

```swift
import UIKit
import UserNotifications
```

Fonction à remettre dans `enum CloudKitService` :

```swift
// MARK: - Subscription Push Notifications

/// Souscrit aux notifications d'annonces via CKQuerySubscription sur la base **publique**.
///
/// Appelé à chaque lancement — CloudKit écrase la subscription existante si même ID.
/// Quand un record **Announcements** est créé (CloudKit Dashboard), tous les utilisateurs
/// reçoivent une notification push.
///
/// Config Dashboard (en Development puis Deploy) : type `Announcements` avec `title` (String,
/// QUERYABLE) + `body` (String). Voir ARCHIVE_notifications-distantes.md.
/// - Returns: `nil` si enregistrée, sinon un message d'erreur lisible.
@discardableResult
static func subscribeToAnnouncements() async -> String? {
    // WHY: NSPredicate(value: true) / TRUEPREDICATE est REFUSÉ en Production (CKError 12
    // « attempting to create a subscription in a production container »). Production exige
    // un prédicat réel sur un champ QUERYABLE. `title != ""` matche toutes les annonces.
    let predicate = NSPredicate(format: "title != %@", "")
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
```

### 4.2 `FinoriaApp.swift` — appel au lancement

Dans `init()`, dans le bloc `if let container { … }`, après les NotificationManager :

```swift
// Subscription CloudKit pour les notifications push (annonces)
Task {
    await CloudKitService.subscribeToAnnouncements()
}
```

### 4.3 `CloudKitService.swift` — diagnostic in-app (debug, optionnel)

```swift
// MARK: - Diagnostic Push (debug TestFlight)

/// Récupère toutes les subscriptions de la base publique pour le compte iCloud courant.
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
/// Vérifie : compte iCloud, permission notifications, inscription APNs, subscription.
static func diagnosePush() async -> String {
    var lines: [String] = []

    let status = await checkAccountStatus()
    lines.append("iCloud : " + (status.isAvailable ? "✅ connecté" : "❌ \(status.alertTitle)"))

    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
        lines.append("Notifications : ✅ autorisées")
    case .denied:
        lines.append("Notifications : ❌ refusées\n→ Réglages › Finoria › Notifications")
    case .notDetermined:
        lines.append("Notifications : ⏳ jamais demandées (relance l'app)")
    @unknown default:
        lines.append("Notifications : ❓ statut inconnu")
    }

    let registered = await MainActor.run { UIApplication.shared.isRegisteredForRemoteNotifications }
    lines.append("APNs : " + (registered ? "✅ enregistré" : "❌ non enregistré"))

    do {
        let subs = try await fetchAllPublicSubscriptions()
        if subs.contains(where: { $0.subscriptionID == "all-announcements" }) {
            lines.append("Subscription : ✅ active (all-announcements)")
        } else {
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
```

### 4.4 `HomeTabView.swift` — déclencheur du diagnostic (appui long sur le bouton import)

États :
```swift
@State private var showPushDiagnostic = false
@State private var pushDiagnosticText = ""
```

Sur le `Button` d'import CSV :
```swift
.simultaneousGesture(
    LongPressGesture(minimumDuration: 1.5).onEnded { _ in
        runPushDiagnostic()
    }
)
```

Alerte (à côté des autres `.alert`) :
```swift
.alert("Diagnostic notifications", isPresented: $showPushDiagnostic) {
    Button("OK", role: .cancel) {}
} message: {
    Text(pushDiagnosticText)
}
```

Fonction :
```swift
private func runPushDiagnostic() {
    Task {
        let report = await CloudKitService.diagnosePush()
        await MainActor.run {
            pushDiagnosticText = report
            showPushDiagnostic = true
        }
    }
}
```

### 4.5 `Localizable.strings` — clés de localisation des annonces

```
/* Notifications push CloudKit — Annonces */
/* %1$@ est remplacé par la valeur du champ correspondant du record Announcements */

"CK_ANNOUNCEMENT_TITLE" = "%1$@";
"CK_ANNOUNCEMENT_BODY" = "%1$@";
```

### 4.6 (Historique) clé UserDefaults supprimée plus tôt

Une `AppStorageKeys.cloudKitAnnouncementsSubscriptionSaved` servait à ne pas recréer la
subscription à chaque lancement. Elle a été retirée car le verrou se désynchronisait du
serveur (subscription perdue mais flag à `true` → jamais recréée). Si on réessaie : **ne
pas** réintroduire ce verrou ; appeler `subscribeToAnnouncements()` à chaque lancement
(CloudKit déduplique par `subscriptionID`).

---

## 5. Alternative à explorer si on réessaie

Apple propose depuis iOS 16 les **Broadcast Push Notifications** (canaux APNs, visibles dans
le Push Notifications Console : « Send broadcast notification on channel »). Plus simple que
les query subscriptions CloudKit (pas de subscription par-utilisateur), mais nécessite
d'activer la « broadcast capability » et d'enregistrer l'app sur un canal côté code. À
évaluer comme remplaçant si la 2e tentative via CloudKit reste pénible.
