# Back map

One rule for the phone Back button, the Android Back gesture and the browser Back button. Code: `lib/nav/back_guard.dart` (`AppRoute`, `BackGuard`). A test (`test/back_map_test.dart`) fails when a screen is missing from this file.

## The rule (top to bottom, first match wins)
1. Lock screen is showing: Back never touches the screens under it. First press shows "Tekan sekali lagi untuk keluar".
2. A pop-up, menu or bottom sheet is open: Back closes only that.
3. A screen has its own steps (marked **own steps** below): Back goes one step back inside it.
4. A pushed screen: Back returns to the screen that opened it.
5. Inside the app shell (Home, Members, Explore, Chat, Profile): Back returns to the tab you were on before, then to Home.
6. Nothing left (first screen of the app): phone shows "Tekan sekali lagi untuk keluar"; a second Back within 2 seconds leaves. The browser never leaves (Back does nothing).

Wrong before this change: in the first-run chain (Welcome, Verification, Consent, PIN offer, first profile) the Welcome screen stayed under Consent, PIN and first profile, so Back walked to a stale Welcome. Now those screens are the first screen, so Back asks to exit.

## First screen of the app (rule 6)
| Screen | Back does |
|---|---|
| WelcomeScreen | exit hint |
| ReturningScreen (web) | exit hint |
| LockScreen | exit hint (screens under it stay put) |
| ConsentScreen | exit hint (it has its own "Kembali" button that signs out to Welcome) |
| PinSetupScreen | exit hint |
| FirstLoginProfileScreen | exit hint |
| HomeShell | rule 5, then exit hint |

## Sign in
| Screen | Opened from | Back goes to |
|---|---|---|
| VerificationScreen | WelcomeScreen, ReturningScreen | the screen that opened it |
| ContactAdminScreen | VerificationScreen, HelpScreen | the screen that opened it |
| DeleteAccountScreen | SettingsScreen | SettingsScreen (after deleting: WelcomeScreen as first screen) |
| PolicyScreen | ProfileDetailScreen | ProfileDetailScreen |

## App shell tabs (rule 5)
| Screen | Back goes to |
|---|---|
| HomeScreen | exit hint (it is the Home tab) |
| AlumniScreen, DirectoryScreen | previous tab, then Home |
| MarketScreen | previous tab, then Home |
| MarketplaceScreen, BusinessDirectoryScreen, JobBoardScreen | when a tab segment: previous tab, then Home; when opened with a back arrow: the screen that opened it |
| MessagesListScreen, ChatScreen | previous tab, then Home (Chat is switched off) |
| ProfileDetailScreen (own profile tab) | previous tab, then Home |
| ProfileDetailScreen (someone else) | the screen that opened it |

## Pushed from Home and tabs
| Screen | Opened from | Back goes to |
|---|---|---|
| NotificationsScreen, RequestsScreen, AnnouncementsScreen, AnnouncementDetailScreen, KontakIkafeScreen | Home | Home |
| JobDetailScreen | JobBoardScreen, notifications | the list |
| ApplyJobScreen **own steps** | JobDetailScreen | review goes to details; done goes to JobDetailScreen; details goes to JobDetailScreen |
| JobApplicantsScreen | JobDetailScreen, MyJobPostingsScreen, notifications | the screen that opened it |
| PostJobScreen | MyJobPostingsScreen, JobBoardScreen | the screen that opened it |
| MarketplaceDetailScreen | MarketplaceScreen | the list |
| MarketplaceFormScreen | MarketplaceScreen, MyListingsScreen | the screen that opened it |
| MyListingsScreen | MarketplaceScreen, notifications | the screen that opened it |
| BusinessDetailScreen | BusinessDirectoryScreen | the list |
| BusinessFormScreen | MyBusinessesScreen, BusinessDirectoryScreen, Home | the screen that opened it |
| MyBusinessesScreen | Home, ProfileDetailScreen, BusinessDirectoryScreen, notifications | the screen that opened it |
| MyJobPostingsScreen | ProfileDetailScreen, JobBoardScreen | the screen that opened it |
| FeatureIntroScreen | SettingsScreen | SettingsScreen |

## Profile
| Screen | Opened from | Back goes to |
|---|---|---|
| SettingsScreen | ProfileDetailScreen | ProfileDetailScreen |
| HelpScreen, AboutScreen | ProfileDetailScreen, HelpScreen | the screen that opened it |
| BlockedUsersScreen | SettingsScreen | SettingsScreen |
| DefaultContactScreen | SettingsScreen, FirstLoginProfileScreen | the screen that opened it |
| PinSettingsScreen **own steps** | SettingsScreen | the verify step goes to the PIN menu; the menu goes to SettingsScreen |
| PinSetupScreen (from PIN settings) | PinSettingsScreen | PinSettingsScreen |
| ProfileSetupScreen, ProfileBioScreen, ProfileCityScreen, ProfileLinkedInScreen, ProfilePhotoScreen | ProfileDetailScreen, HomeScreen, FirstLoginProfileScreen | the screen that opened it |
| PhotoAdjustScreen | any photo picker (profile photo, business, product, job, sponsor forms) | the form that opened it (no arrow in the bar; Back or its buttons) |

## Admin (all go back to the screen that opened them)
| Screen | Opened from | Back goes to |
|---|---|---|
| AdminScreen | ProfileDetailScreen | ProfileDetailScreen |
| AdminMembersScreen | AdminScreen | AdminScreen |
| AdminMemberEditScreen **own steps** | AdminMembersScreen | with unsaved changes a "Buang perubahan?" dialog first, then AdminMembersScreen |
| AdminAdminsScreen, _PickMemberScreen | AdminScreen | the screen that opened it |
| AdminAnnouncementsScreen, AnnouncementFormScreen | AdminScreen | the screen that opened it |
| AdminBusinessesScreen, AdminBusinessDetailScreen | AdminScreen, notifications | the screen that opened it |
| MarketplaceAdminScreen, AdminProductDetailScreen | AdminScreen | the screen that opened it |
| AdminJobsScreen | AdminScreen | AdminScreen |
| AdminReportsScreen | AdminScreen, notifications | the screen that opened it |
| AdminFeedbackScreen, AdminLogScreen, AdminHomeOrderScreen | AdminScreen | AdminScreen |
| AdminIkafeContactsScreen, IkafeContactFormScreen | AdminScreen | the screen that opened it |
| AdminSponsorsScreen, SponsorFormScreen | AdminScreen | the screen that opened it |

## Pop-ups, sheets, links
- Dialogs, menus and bottom sheets: Back closes them first (rule 2). No dialog blocks Back.
- Web: tab changes replace the address (`/members`, `/explore/jobs`), they do not add browser history. Browser Back uses the same rule; at the first screen it does nothing and the page is never left.
- Deep links: a web address only picks the tab after the PIN screen. The app always starts at the entry screen, so a link never skips the lock.
- Android: `enableOnBackInvokedCallback` is on; the app tells Android it handles Back on every first screen and while locked (tested in `test/back_android_test.dart`).
