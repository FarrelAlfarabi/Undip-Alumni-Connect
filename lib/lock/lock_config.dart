// Tunable numbers for the device lock screen, in one place.

/// How long the app may stay in the background before the lock screen shows
/// again. One named constant, as requested.
const Duration kLockAfterBackground = Duration(minutes: 5);

/// PIN length. Six digits.
const int kPinLength = 6;

/// This many wrong PINs in a row wipe the local unlock data and require a
/// full verification.
const int kMaxPinAttempts = 5;

/// From this many wrong tries on, the next try must wait [kWrongPinDelay].
const int kDelayAfterAttempts = 3;
const Duration kWrongPinDelay = Duration(seconds: 10);

/// PBKDF2-HMAC-SHA256 work factor. Pure Dart, so this is a trade-off between
/// unlock speed on a low-end phone and cost of an offline guess. A 6-digit
/// PIN only has 1,000,000 possibilities, so this can slow guessing down but
/// cannot stop it; the real limit is the 5-attempt wipe. See README.
const int kPinHashIterations = 60000;
