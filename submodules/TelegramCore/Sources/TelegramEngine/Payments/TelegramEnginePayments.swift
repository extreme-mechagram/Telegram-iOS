import Foundation
import SwiftSignalKit
import Postbox

// MECHAGRAM_DEMO_POLICY_BEGIN
func mechagramDemoBalanceAfterPurchase(raw: String, value: Int64, nanos: Int32, isTon: Bool) -> String? {
    guard let balance = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !balance.isNaN, balance >= 0, balance <= 1_000_000_000_000, value >= 0, nanos >= 0, nanos < 1_000_000_000 else { return nil }
    let cost = (Decimal(value) + Decimal(nanos) / 1_000_000_000) / (isTon ? 1_000_000_000 : 1)
    guard balance >= cost else { return nil }
    return NSDecimalNumber(decimal: balance - cost).stringValue
}
// MECHAGRAM_DEMO_POLICY_END

public extension TelegramEngine {
    final class Payments {
        private let account: Account
        
        init(account: Account) {
            self.account = account
        }

        public func mechagramRefreshLocalGiftStatus() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                let peerId = self.account.peerId
                guard let user = transaction.getPeer(peerId) as? TelegramUser else { return }
                let updated: TelegramUser
                if mechagramLocalWearStatus(peerId: peerId) != nil {
                    let entries = mechagramReadProfileGifts(accountId: peerId, peerId: peerId)
                    for entry in entries {
                        if case let .unique(gift) = entry.gift, mechagramLocalGiftIsWorn(peerId: peerId, giftId: gift.id) {
                            for attribute in gift.attributes {
                                switch attribute {
                                case let .model(_, file, _, _), let .pattern(_, file, _): transaction.storeMediaIfNotPresent(media: file)
                                default: break
                                }
                            }
                        }
                    }
                    updated = mechagramOverlayLocalWear(user)
                } else {
                    let overlayKey = "mechagram.giftStatusOverlaid.v1.\(peerId.toInt64())"
                    guard UserDefaults.standard.bool(forKey: overlayKey) else { return }
                    let key = "mechagram.originalGiftStatus.v1.\(peerId.toInt64())"
                    let original = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(PeerEmojiStatus.self, from: $0) }
                    updated = user.withUpdatedEmojiStatus(original)
                    UserDefaults.standard.removeObject(forKey: key)
                    UserDefaults.standard.removeObject(forKey: overlayKey)
                }
                updatePeersCustom(transaction: transaction, peers: [updated], update: { _, value in value })
            } |> ignoreValues
        }

        public func mechagramTransferLocalGift(giftId: Int64, recipientId: EnginePeer.Id) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                guard let gift = mechagramUpdateLocalGift(accountId: self.account.peerId, giftId: giftId, recipientId: recipientId) else { return false }
                let action = TelegramMediaAction(action: .starGiftUnique(gift: .unique(gift), isUpgrade: false, isTransferred: true, savedToProfile: true, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: nil, senderId: nil, savedId: nil, resaleAmount: nil, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: nil, isCrafted: false))
                let message = StoreMessage(id: .Partial(recipientId, Namespaces.Message.Local), customStableId: nil, globallyUniqueId: Int64.random(in: 1 ... Int64.max), groupingKey: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.account.peerId, text: "mechagram:local-gift:v2", attributes: [], media: [action])
                let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
                return true
            }
        }

        public func mechagramDeleteLocalGift(peerId: EnginePeer.Id, giftId: Int64) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { _ -> Bool in
                return _internal_mechagramDeleteLocalGift(accountId: self.account.peerId, peerId: peerId, giftId: giftId)
            }
        }

        // Local preview only: no outgoing queue, payment form or network request.
        public func mechagramSimulateGift(
            peerId: EnginePeer.Id,
            gift: StarGift,
            price: CurrencyAmount,
            text: String? = nil,
            entities: [MessageTextEntity] = [],
            nameHidden: Bool = false
        ) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                return mechagramWithProfileGiftLock {
                let settings = UserDefaults.standard
                let visualGiftsEnabled = settings.object(forKey: "mechagram.visualGifts") as? Bool ?? true
                guard visualGiftsEnabled else {
                    return false
                }
                guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId == self.account.peerId else {
                    return false
                }
                let isTon = price.currency == .ton
                let key = isTon ? "mechagram.visualTON" : "mechagram.visualStars"
                let raw = settings.string(forKey: key) ?? (isTon ? "1000.0" : "100000")
                let remaining = mechagramDemoBalanceAfterPurchase(raw: raw, value: price.amount.value, nanos: price.amount.nanos, isTon: isTon) ?? (isTon ? "1000.0" : "100000")
                let gift = mechagramGiftForRecipient(gift, peerId: peerId)
                let marker = "mechagram:local-gift:v2"
                let action: TelegramMediaAction
                let isSelf = (peerId == self.account.peerId)
                switch gift {
                case let .generic(genericGift):
                    action = TelegramMediaAction(action: .starGift(gift: gift, convertStars: genericGift.convertStars, text: text, entities: entities, nameHidden: nameHidden, savedToProfile: true, converted: false, upgraded: false, canUpgrade: genericGift.upgradeStars != nil, upgradeStars: genericGift.upgradeStars, isRefunded: false, isPrepaidUpgrade: false, upgradeMessageId: nil, peerId: peerId, senderId: isSelf ? nil : self.account.peerId, savedId: nil, prepaidUpgradeHash: nil, giftMessageId: nil, upgradeSeparate: false, isAuctionAcquired: false, toPeerId: peerId, number: nil))
                case .unique:
                    action = TelegramMediaAction(action: .starGiftUnique(gift: gift, isUpgrade: false, isTransferred: false, savedToProfile: true, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: peerId, senderId: isSelf ? nil : self.account.peerId, savedId: nil, resaleAmount: price, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: nil, isCrafted: false))
                }
                var profileGifts = mechagramReadProfileGifts(accountId: self.account.peerId, peerId: peerId)
                if case let .unique(value) = gift {
                    profileGifts.removeAll { if case let .unique(other) = $0.gift { return other.id == value.id }; return false }
                }
                profileGifts.insert(ProfileGiftsContext.State.StarGift(
                    gift: gift, reference: nil,
                    fromPeer: isSelf ? nil : transaction.getPeer(self.account.peerId).map(EnginePeer.init),
                    date: Int32(Date().timeIntervalSince1970), text: text, entities: entities,
                    nameHidden: nameHidden, savedToProfile: true, pinnedToTop: false, convertStars: nil,
                    canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: nil,
                    canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil,
                    upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil,
                    isRefunded: false, canCraftAt: nil
                ), at: 0)
                guard mechagramStoreProfileGifts(profileGifts, accountId: self.account.peerId, peerId: peerId) else { return false }
                if case let .unique(value) = gift { mechagramRemoveOtherLocalOwners(giftId: value.id, recipientId: peerId) }
                let message = StoreMessage(id: .Partial(peerId, Namespaces.Message.Local), customStableId: nil, globallyUniqueId: Int64.random(in: 1 ... Int64.max), groupingKey: nil, threadId: nil, timestamp: Int32(Date().timeIntervalSince1970), flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.account.peerId, text: marker, attributes: [], media: [action])
                let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
                settings.set(remaining, forKey: key)
                if case let .unique(value) = gift {
                    mechagramRecordLocalMarketPurchase(accountId: self.account.peerId.toInt64(), giftTypeId: value.giftId, giftId: value.id)
                }

                let recipientPeer = transaction.getPeer(peerId)
                let recipientTitle = recipientPeer?.debugDisplayTitle ?? "Recipient"
                let negativeAmount = CurrencyAmount(amount: StarsAmount(value: -abs(price.amount.value), nanos: price.amount.nanos), currency: price.currency)
                let isMarketResale: Bool
                if case .unique = gift {
                    isMarketResale = true
                } else {
                    isMarketResale = false
                }
                let localTx = MechagramLocalStarTransaction(
                    id: "local_\(Int64.random(in: 100000...999999))_\(Int32(Date().timeIntervalSince1970))",
                    count: negativeAmount,
                    date: Int32(Date().timeIntervalSince1970),
                    peerId: peerId.toInt64(),
                    peerTitle: recipientTitle,
                    isTon: isTon,
                    isMarketResale: isMarketResale,
                    starGift: gift
                )
                mechagramRecordLocalTransaction(accountId: self.account.peerId, transaction: localTx, notify: false)
                return true
                }
            }
            |> map { success in
                if success {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("MechagramLocalTransactionsChanged"), object: nil)
                        NotificationCenter.default.post(name: Notification.Name("MechagramLocalProfileGiftsChanged"), object: nil)
                    }
                }
                return success
            }
        }
        
        public func getBankCardInfo(cardNumber: String) -> Signal<BankCardInfo?, NoError> {
            return _internal_getBankCardInfo(account: self.account, cardNumber: cardNumber)
        }
        
        public func fetchBotPaymentInvoice(source: BotPaymentInvoiceSource) -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> {
            return _internal_fetchBotPaymentInvoice(postbox: self.account.postbox, network: self.account.network, source: source)
        }
        
        public func fetchBotPaymentForm(source: BotPaymentInvoiceSource, themeParams: [String: Any]?) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
            return _internal_fetchBotPaymentForm(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, source: source, themeParams: themeParams)
        }
        
        public func validateBotPaymentForm(saveInfo: Bool, source: BotPaymentInvoiceSource, formInfo: BotPaymentRequestedInfo) -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError> {
            return _internal_validateBotPaymentForm(account: self.account, saveInfo: saveInfo, source: source, formInfo: formInfo)
        }
        
        public func sendBotPaymentForm(source: BotPaymentInvoiceSource, formId: Int64, validatedInfoId: String?, shippingOptionId: String?, tipAmount: Int64?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
            return _internal_sendBotPaymentForm(account: self.account, formId: formId, source: source, validatedInfoId: validatedInfoId, shippingOptionId: shippingOptionId, tipAmount: tipAmount, credentials: credentials)
        }
        
        public func requestBotPaymentReceipt(messageId: MessageId) -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> {
            return _internal_requestBotPaymentReceipt(account: self.account, messageId: messageId)
        }
        
        public func clearBotPaymentInfo(info: BotPaymentInfo) -> Signal<Void, NoError> {
            return _internal_clearBotPaymentInfo(network: self.account.network, info: info)
        }
        
        public func sendAppStoreReceipt(receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
            return _internal_sendAppStoreReceipt(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, receipt: receipt, purpose: purpose)
        }
        
        public func canPurchasePremium(purpose: AppStoreTransactionPurpose) -> Signal<Bool, NoError> {
            return _internal_canPurchasePremium(postbox: self.account.postbox, network: self.account.network, purpose: purpose)
        }
        
        public func checkPremiumGiftCode(slug: String) -> Signal<PremiumGiftCodeInfo?, NoError> {
            return _internal_checkPremiumGiftCode(account: self.account, slug: slug)
        }
        
        public func applyPremiumGiftCode(slug: String) -> Signal<Never, ApplyPremiumGiftCodeError> {
            return _internal_applyPremiumGiftCode(account: self.account, slug: slug)
        }
        
        public func premiumGiftCodeOptions(peerId: EnginePeer.Id?, onlyCached: Bool = false) -> Signal<[PremiumGiftCodeOption], NoError> {
            return _internal_premiumGiftCodeOptions(account: self.account, peerId: peerId, onlyCached: onlyCached)
        }
        
        public func premiumGiveawayInfo(peerId: EnginePeer.Id, messageId: EngineMessage.Id) -> Signal<PremiumGiveawayInfo?, NoError> {
            return _internal_getPremiumGiveawayInfo(account: self.account, peerId: peerId, messageId: messageId)
        }
        
        public func launchPrepaidGiveaway(peerId: EnginePeer.Id, id: Int64, purpose: LaunchGiveawayPurpose, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32) -> Signal<Never, LaunchPrepaidGiveawayError> {
            return _internal_launchPrepaidGiveaway(account: self.account, peerId: peerId, purpose: purpose, id: id, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate)
        }
        
        public func starsTopUpOptions() -> Signal<[StarsTopUpOption], NoError> {
            return _internal_starsTopUpOptions(account: self.account)
        }
        
        public func starsGiftOptions(peerId: EnginePeer.Id?) -> Signal<[StarsGiftOption], NoError> {
            return _internal_starsGiftOptions(account: self.account, peerId: peerId)
        }
        
        public func starsGiveawayOptions() -> Signal<[StarsGiveawayOption], NoError> {
            return _internal_starsGiveawayOptions(account: self.account)
        }
        
        public func peerStarsContext() -> StarsContext {
            return StarsContext(account: self.account, ton: false)
        }
        
        public func peerTonContext() -> StarsContext {
            return StarsContext(account: self.account, ton: true)
        }
        
        public func peerStarsRevenueContext(peerId: EnginePeer.Id, ton: Bool) -> StarsRevenueStatsContext {
            return StarsRevenueStatsContext(account: self.account, peerId: peerId, ton: ton)
        }
        
        public func peerStarsTransactionsContext(subject: StarsTransactionsContext.Subject, mode: StarsTransactionsContext.Mode) -> StarsTransactionsContext {
            return StarsTransactionsContext(account: self.account, subject: subject, mode: mode)
        }
        
        public func peerStarsSubscriptionsContext(starsContext: StarsContext?, missingBalance: Bool = false) -> StarsSubscriptionsContext {
            return StarsSubscriptionsContext(account: self.account, starsContext: starsContext, missingBalance: missingBalance)
        }
        
        public func sendStarsPaymentForm(formId: Int64, source: BotPaymentInvoiceSource) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
            return _internal_sendStarsPaymentForm(account: self.account, formId: formId, source: source)
        }
        
        public func fulfillStarsSubscription(peerId: EnginePeer.Id, subscriptionId: String) -> Signal<Never, FulfillStarsSubsciptionError> {
            return _internal_fulfillStarsSubscription(account: self.account, peerId: peerId, subscriptionId: subscriptionId)
        }
        
        public func cachedStarGifts() -> Signal<[StarGift]?, NoError> {
            return _internal_cachedStarGifts(postbox: self.account.postbox)
            |> map { starGiftsList in
                return starGiftsList?.items
            }
        }
        
        public func keepStarGiftsUpdated() -> Signal<Never, NoError> {
            return _internal_keepCachedStarGiftsUpdated(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId)
        }
        
        public func convertStarGift(reference: StarGiftReference) -> Signal<Never, NoError> {
            return _internal_convertStarGift(account: self.account, reference: reference)
        }
        
        public func updateStarGiftAddedToProfile(reference: StarGiftReference, added: Bool) -> Signal<Never, NoError> {
            return _internal_updateStarGiftAddedToProfile(account: self.account, reference: reference, added: added)
        }
        
        public func dropStarGiftOriginalDetails(reference: StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError> {
            return _internal_dropStarGiftOriginalDetails(account: self.account, reference: reference)
        }
        
        public func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError> {
            return _internal_transferStarGift(account: self.account, prepaid: prepaid, reference: reference, peerId: peerId)
        }
        
        public func buyStarGift(slug: String, peerId: EnginePeer.Id, price: CurrencyAmount?) -> Signal<Never, BuyStarGiftError> {
            return _internal_buyStarGift(account: self.account, slug: slug, peerId: peerId, price: price)
        }
        
        public func upgradeStarGift(formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
            return _internal_upgradeStarGift(account: self.account, formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
        }
        
        public func starGiftUpgradePreview(giftId: Int64) -> Signal<StarGiftUpgradePreview?, NoError> {
            return _internal_starGiftUpgradePreview(account: self.account, giftId: giftId)
        }
        
        public func checkCanSendStarGift(giftId: Int64) -> Signal<CanSendGiftResult, NoError> {
            return _internal_checkCanSendStarGift(account: self.account, giftId: giftId)
        }
        
        public func getUniqueStarGift(slug: String) -> Signal<StarGift.UniqueGift, GetUniqueStarGiftError> {
            return _internal_getUniqueStarGift(account: self.account, slug: slug)
        }
        
        public func getUniqueStarGiftValueInfo(slug: String) -> Signal<StarGift.UniqueGift.ValueInfo?, NoError> {
            return _internal_getUniqueStarGiftValueInfo(account: self.account, slug: slug)
        }
                
        public func checkStarGiftWithdrawalAvailability(reference: StarGiftReference) -> Signal<Never, RequestStarGiftWithdrawalError> {
            return _internal_checkStarGiftWithdrawalAvailability(account: self.account, reference: reference)
        }
        
        public func requestStarGiftWithdrawalUrl(reference: StarGiftReference, password: String) -> Signal<String, RequestStarGiftWithdrawalError> {
            return _internal_requestStarGiftWithdrawalUrl(account: account, reference: reference, password: password)
        }
        
        public func toggleStarGiftsNotifications(peerId: EnginePeer.Id, enabled: Bool) -> Signal<Never, NoError> {
            return _internal_toggleStarGiftsNotifications(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func updateStarGiftResalePrice(reference: StarGiftReference, price: CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError> {
            return _internal_updateStarGiftResalePrice(account: self.account, reference: reference, price: price)
        }
        
        public func getGiftAuctionAcquiredGifts(giftId: Int64) -> Signal<[GiftAuctionAcquiredGift], NoError> {
            return _internal_getGiftAuctionAcquiredGifts(account: self.account, giftId: giftId)
        }
        
        public func getStarsTransaction(reference: StarsTransactionReference) -> Signal<StarsContext.State.Transaction?, NoError> {
            return _internal_getStarsTransaction(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, transactionReference: reference)
        }
        
        public func resolveStarGiftOffer(messageId: EngineMessage.Id, accept: Bool) -> Signal<Never, ResolveStarGiftOfferError> {
            return _internal_resolveStarGiftOffer(account: self.account, messageId: messageId, accept: accept)
        }
 
        public func sendStarGiftOffer(peerId: EnginePeer.Id, slug: String, amount: CurrencyAmount, duration: Int32, allowPaidStars: Int64?) -> Signal<Never, SendStarGiftOfferError> {
            return _internal_sendStarGiftOffer(account: self.account, peerId: peerId, slug: slug, amount: amount, duration: duration, allowPaidStars: allowPaidStars)
        }
        
        public func getStarGiftUpgradeAttributes(giftId: Int64) -> Signal<[StarGift.UniqueGift.Attribute]?, NoError> {
            return _internal_getStarGiftUpgradeAttributes(account: self.account, giftId: giftId)
        }
    }
}

public extension TelegramEngineUnauthorized {
    final class Payments {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func canPurchasePremium(purpose: AppStoreTransactionPurpose) -> Signal<Bool, NoError> {
            return _internal_canPurchasePremium(postbox: self.account.postbox, network: self.account.network, purpose: purpose)
        }
        
        public func sendAppStoreReceipt(receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
            return _internal_sendAppStoreReceipt(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, receipt: receipt, purpose: purpose)
        }
    }
}
