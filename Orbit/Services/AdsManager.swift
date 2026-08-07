import GoogleMobileAds
import UIKit

// One interstitial per 30 cumulative points scored, shown at game over.
// The counter persists locally across games and app starts; it only resets
// when an ad actually presents, so a not-yet-loaded ad is owed, not skipped.
// Test IDs are Google's public ones — swap in real AdMob IDs before release
// (ad unit below and GADApplicationIdentifier in project.yml).
final class AdsManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AdsManager()
    private static let interstitialID = "ca-app-pub-3940256099942544/4411468910"
    private static let threshold = 30
    private static let counterKey = "ads.scoreSinceLastAd"

    private var interstitial: GADInterstitialAd?

    func start() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        load()
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
