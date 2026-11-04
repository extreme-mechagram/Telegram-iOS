# Mechagram revision 9

Display balances are shared by Settings, gift catalog/store, purchase/transfer and balance overlays. The actual server balances remain intact.

Remote message deletion retains previously cached cloud messages, including zero or unstarted autoremove timers; expired messages, disappearing media and secret chats follow their original lifecycle. History validation preserves retained messages. MechagramRetention logs contain reasons only, without message text or account identifiers.

Enable both visual balances and local gifts in Mechagram settings to simulate catalog/market gifts. The local transaction spends the DEMO balance and inserts a card with a DEMO notice without unsent/sending flags or network requests. Other devices cannot see local cards. Regular and collectible gifts are supported in private chats; real purchases remain separate.

CI compiles and runs 13 cases against the production retention and decimal spending policies before building the IPA. Device validation is still required.

## Local profile gifts

New catalog and market copies are persisted per account and recipient and included in profile gifts on this device, including users with no server gifts. They have no server gift reference. Existing chat-only cards are not migrated. Profile contexts refresh after a new local gift is created.

The Confirm each local gift switch defaults to enabled and applies to catalog and market copies. Turning it off creates the local copy immediately. DEMO and visual labels are removed from affected screens; the on-device explanation remains. No server payments or gift ownership changes are performed by local creation.

## Local gift presentation corrections

The v2 confirmation preference defaults to off, independently of the previous default-on preference. Its production tests cover unset, legacy-on, explicit-on and explicit-off states. The optional confirmation no longer contains the old local-copy notice; the Mechagram settings still explain the device-only behavior.

Collectible copies use the recipient as their local owner and clear listing price, TON-only sale, host, on-chain address and purchase-offer state. This normalization also applies to existing local profile entries and old local chat gift detail screens. Catalog/market model, backdrop, pattern and collectible number are preserved. Native chat cards and their view action are restored. Local references cannot be converted to server gift references, and local copies have no server trading controls.

A static review of the supplied Android eblannft_v.plugin found a Python bootstrap, embedded Python modules and a DEX core. It sets owner references and listing fields in gift models and lets native Telegram views render them. Android hooks, updater and sync code are not imported into iOS.

## Settings-driven confirmation bypass and account-local market visibility

The explicit Send gifts without confirmation switch is enabled by default. Settings reads and writes the same public policy used by the catalog and resale flows. Both flows dispatch through mechagramPerformGiftAction; confirmation controllers are constructed only inside its confirm callback. The setter also writes inverse legacy values for older builds. Tests exercise the settings setter and dispatcher together, including persisted values and both toggle directions.

Completed local collectible creation records the unique gift ID per account and gift family. Resale contexts observe purchase notifications and filter those IDs from visible results without changing server pagination data. An empty page containing hidden purchases advances to the next cursor; repeated cursors are not retried automatically. New contexts use the persisted IDs. Existing local profile gift records are imported once per account. Other accounts and devices retain their own market view; server listings are unchanged.

The Foundation production-policy suite now runs 31 assertions, including persistence, account/family isolation, large IDs, idempotent purchase records and concurrent updates.

## Shared previews and local collectible controls (build 18)

Local profile gifts now use one recipient store across accounts in the installation. Old account-specific profile stores migrate once without restoring transferred records. Owned collectible previews expose transfer, wear/take off and list/unlist controls. Transfer changes the profile owner and clears resale metadata; sale price persists locally. Wearing updates a local status overlay and never calls Telegram status/payment APIs. Local resale detail screens do not fetch real payment forms.

An isolated VDS service shares collectible preview metadata across installations over pinned HTTPS. The app uses a persistent outbox and cached public profile reads; open profiles refresh every 15 seconds. A profile with no official gifts gains its gift pane when shared previews arrive. Authentication identifies installations only, not Telegram identities. Latest published preview for a collectible wins; this is not an ownership registry or a real sale. See port/sync/README.md for protocol limits and deployment isolation. Regular noncollectible gifts remain local.

Hide mod settings entry removes only the settings row. Existing feature preferences remain active. Hold Appearance in Telegram settings to restore and open Mechagram.

Local syntax checks and backend protocol tests passed before push. Full Swift compilation and iPhone validation remain pending until CI/device results. At the user's request, stop following CI when the compilation step starts.

## Three-dot action menu and realistic gift presentation (build 19)

Local and visual collectible gifts now display the native three-dot more menu on profile gift cards across own and other profiles. Context menu actions expose link copying, sharing, local transfer, and viewing the owner's profile without local-gift restrictions. Simulated gift and market purchases in chat identify the correct recipient and sender IDs, clear false transfer flags, and attach resale amounts so gift announcements render as gifts rather than generic transfers or self-purchases.

### Profile Gift Deletion, Visual Stars Transactions, and Gift Signatures
- **Local Profile Gift Deletion**: Profile gifts now expose a destructive "Delete" action in the 3-dot context menu for both collectible and regular visual gifts. Selecting delete removes the entry from the shared local store, clears any active wear status, and posts updates to synchronize profile views.
- **Visual Stars & TON Transactions**: Purchases and gift operations now generate simulated outgoing local transactions. These transactions integrate seamlessly into `StarsContext` and `StarsTransactionsContext`, appearing with the correct recipient title, negative amount, and gift icon/subtitle in the Telegram Stars history tabs.
- **Visual Gift Captions/Signatures**: Fixed `GiftSetupScreen` omitting user message input when sending visual gifts; input text, formatting entities, and sender name visibility are now properly forwarded to `mechagramSimulateGift` and recorded on the gift card and chat announcement.
- **Custom Server Configuration & Debug Access**: Enhanced authorization screen 10-tap detection on the phone number / title field to open debug settings reliably. Added "Добавить свой сервер" in the debug menu allowing users to configure custom server name, IP address, port, and RSA key. The active server name is now prominently shown next to each account in the account switcher menu and debug accounts list.


# Mechagram revision 10

- Gift sending freeze fixed: immediate dismiss of GiftSetupScreen modal upon send action with Confetti feedback.
- Server selector added to Add Account action and Registration splash screen: easily switch between Official Telegram and Custom Server.
- Automatic custom server MTProto network routing applied on UnauthorizedAccount creation and phone entry screen.
- Server indicator displayed in the account switcher menu.

## Gift sending and custom server regression repair (2026-11-04)

Gift recording previously acquired mechagramTransactionsLock, then called the public reader which acquired that same NSLock. The writer now calls an unlocked reader under its existing lock. Transaction notifications occur after unlock; simulated gift creation queues UI notifications after releasing the profile lock and completing its Postbox transaction. Catalog and market flows handle false results without navigating as if creation succeeded, and expose progress while creating.

Custom server selection is captured per AccountRecordId before initializing MTProto. A login controller can switch its unauthorized network; existing authorized networks retain their bound configuration. Custom RSA keys are passed explicitly into MTDatacenterAuthMessageService via MTContext; MTEncryption runtime hooks and guessed fingerprint fallbacks are removed. Transport discovery uses only custom addresses while a custom server is selected. Official fallback source is verified against the previously approved upstream blobs after stripping only these explicit custom branches.

A read-only req_pq_multi probe of 177.3.213.27 succeeded on TCP 443 and 2398; the server fingerprint 18c3579ed10fe05d matches the bundled custom public key. This verifies transport and key agreement, not full account login.

CI regression tests execute the production transaction storage with a bounded timeout, synchronous observer reentry and 32 concurrent writes, plus custom port/key parsing and account binding isolation. Full device validation remains required. Stop following CI when IPA compilation starts, per the user's existing preference.

## Telegram 13.1.2 and Visuals (2026-11-04)

Merged official TelegramMessenger/Telegram-iOS master 279f89e4d4f63f17227bf877dc3d8990f22ecd58 (13.1.2) into the mod, retaining gift persistence, the transaction deadlock repair, per-account custom MTProto configuration and standalone storage for Esign. Build tooling follows upstream Xcode 27.1 / Bazel 9.2.0 on the documented xcode-27 arm64 runner. The new upstream minimum is iOS 15. Native wallet modules and settings are included; the upstream WalletConfiguration availability gate is retained.

Native wallet gift menus are kept intact; local profile-copy actions use a separate local menu. Unique-gift messages adopt the new text/entities/nameHidden fields. Local purchases retain the shared skip-confirmation preference and do not require a real payment form. Custom servers continue to use the MTProtoKit engine because their explicit custom key/address context is not part of the new Rust network engine. Official networks retain the upstream engine selection.

Mod settings now open Visuals: UIKit's color palette applies accents to native Telegram appearance settings, with light, dark and tinted-dark selections. Native appearance opens the wallpaper editor. The Display.Font factory supports rounded, serif and monospace application fonts with a restart for existing views.

Per-peer local profile settings include +888 phone formatting, a collectible-style username, a verification badge, nickname font, avatar ring/beads/gem/sparkles with circle/rounded/square/hexagonal outlines, and profile-header color/image. Only profile rendering receives these metadata overlays; account authentication, stored peers, contact data and wallet ownership remain real. Image import uses bounded thumbnail decoding and private app storage. Existing profile nodes refresh through a style-change notification; profile reset and disable restore native rendering.

Validation: production visual-model tests cover phone/username/color validation, per-peer isolation, persistence, disable/reset and corrupted preferences. Gift policy, deadlock and server-isolation tests remain in CI. Network fallback verification now compares against the new official source blobs after stripping explicit custom branches. Windows checks cover syntax (with two known unsupported constructs already present upstream), merge-marker absence and network fallback hashes; device UI verification is pending.
