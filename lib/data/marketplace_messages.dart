import 'marketplace_repository.dart';

/// User-facing text for a failed marketplace action.
String marketplaceErrorMessage(Object error) {
  if (error is MarketplaceException) {
    switch (error.code) {
      case MarketplaceErrorCode.postingClosed:
        return kPostingClosedMessage;
      case MarketplaceErrorCode.notOwner:
        return 'You can only change your own listings.';
      case MarketplaceErrorCode.notFound:
        return 'This listing no longer exists.';
      case MarketplaceErrorCode.notAdmin:
        return 'Wrong admin passphrase, or you are not an admin.';
      case MarketplaceErrorCode.reasonRequired:
        return 'Give a reason for rejecting.';
      case MarketplaceErrorCode.duplicateReport:
        return 'You already reported this listing.';
      case MarketplaceErrorCode.invalidState:
        return 'This listing cannot be changed in its current state.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Shown while product posting is closed (until it is tied to approved
/// businesses).
const kPostingClosedMessage =
    'Adding products is not open yet. It will open for owners of approved '
    'businesses.';

const kSubmittedMessage =
    'Listing submitted. It will appear in the marketplace once an admin '
    'approves it.';

const kEditedApprovedMessage =
    'Changes saved. Your listing is back in review and hidden until an '
    'admin approves it again.';

const kEditedMessage =
    'Changes saved. Your listing will appear once an admin approves it.';

const kReportSentMessage =
    'Thanks, your report was sent. An admin will take a look.';
