import GoogleMobileAds
import AppTrackingTransparency
import UIKit

// One interstitial per 30 cumulative points scored, shown at game over.
// The counter persists locally across games and app starts; it only resets
// when an ad actually presents, so a not-yet-loaded ad is owed, not skipped.
final class AdsManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AdsManager()

    // Debug builds keep Google's public test unit — clicking your own live
    // ads violates AdMob policy. Release builds use the real unit.
    #if DEBUG
    private static let interstitialID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private static let interstitialID = "ca-app-pub-2662792990353664/8511942614"
    #endif

    private static let threshold = 30
    private static let counterKey = "ads.scoreSinceLastAd"

    private var interstitial: GADInterstitialAd?

    // ATT prompt first (App Store requirement for ad tracking); ads load
    // either way — denied just means non-personalized.
    func start() {
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            DispatchQueue.main.async {
                GADMobileAds.sharedInstance().start(completionHandler: nil)
                self?.load()
            }
        }
    }

    func gameEnded(score: Int) {
        let defaults = UserDefaults.standard
        let total = defaults.integer(forKey: Self.counterKey) + score
        defaults.set(total, forKey: Self.counterKey)
        guard total >= Self.threshold, let ad = interstitial else { return }
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        guard let root else { return }
        defaults.set(total % Self.threshold, forKey: Self.counterKey)
        interstitial = nil
        ad.present(fromRootViewController: root)
    }

    private func load() {
        GADInterstitialAd.load(withAdUnitID: Self.interstitialID,
                               request: GADRequest()) { [weak self] ad, _ in
            guard let self, let ad else { return }
            ad.fullScreenContentDelegate = self
            self.interstitial = ad
        }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        load()
    }
}
