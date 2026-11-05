import '../util/app_language.dart';
import 'marketplace_repository.dart';

/// User-facing text for a failed marketplace action.
String marketplaceErrorMessage(Object error) {
  if (error is MarketplaceException) {
    switch (error.code) {
      case MarketplaceErrorCode.postLimitReached:
        return tr(kPostLimitMessage);
      case MarketplaceErrorCode.businessRequired:
      case MarketplaceErrorCode.businessNotFound:
      case MarketplaceErrorCode.businessNotApproved:
        return tr(kProductsNeedBusinessMessage);
      case MarketplaceErrorCode.notOwner:
        return tr('You can only change your own listings.');
      case MarketplaceErrorCode.notFound:
        return tr('This listing no longer exists.');
      case MarketplaceErrorCode.notAdmin:
        return tr('You are not an admin.');
      case MarketplaceErrorCode.reasonRequired:
        return tr('Give a reason for rejecting.');
      case MarketplaceErrorCode.duplicateReport:
        return tr('You already reported this listing.');
      case MarketplaceErrorCode.invalidState:
        return tr('This listing cannot be changed in its current state.');
      default:
        break;
    }
  }
  return tr('Something went wrong. Please try again.');
}

/// Products can only be added by owners of approved businesses.
const kProductsNeedBusinessMessage =
    'Adding products is for owners of approved businesses. Register your '
    'business first and wait for approval.';

/// At the product limit. No payment instructions on purpose.
const kPostLimitMessage =
    'You have reached the product limit for this business. Your '
    'products stay visible and you can still edit or delete them. To add '
    'more, please contact an admin about unlimited posting.';

const kSubmittedMessage =
    'Product posted. It is now visible in the marketplace.';

const kEditedBusinessMessage = 'Changes saved.';

const kEditedApprovedMessage =
    'Changes saved. Your listing is back in review and hidden until an '
    'admin approves it again.';

const kEditedMessage =
    'Changes saved. Your listing will appear once an admin approves it.';

const kReportSentMessage =
    'Thanks, your report was sent. An admin will take a look.';
