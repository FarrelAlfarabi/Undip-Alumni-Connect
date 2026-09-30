import 'marketplace_repository.dart';

/// User-facing text for a failed marketplace action.
String marketplaceErrorMessage(Object error) {
  if (error is MarketplaceException) {
    switch (error.code) {
      case MarketplaceErrorCode.subscriberRequired:
        return 'Only subscribers can post listings.';
      case MarketplaceErrorCode.notOwner:
        return 'You can only change your own listings.';
      case MarketplaceErrorCode.notFound:
        return 'This listing no longer exists.';
      case MarketplaceErrorCode.invalidState:
        return 'This listing cannot be changed in its current state.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

const kSubmittedMessage =
    'Listing submitted. It will appear in the marketplace once an admin '
    'approves it.';

const kEditedApprovedMessage =
    'Changes saved. Your listing is back in review and hidden until an '
    'admin approves it again.';

const kEditedMessage =
    'Changes saved. Your listing will appear once an admin approves it.';
