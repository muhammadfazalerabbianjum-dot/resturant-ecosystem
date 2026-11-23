// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get firebaseConfigMissing =>
      'Firebase configuration missing - contact the operator';

  @override
  String get appTitle => 'Labs';

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get menu => 'Menu';

  @override
  String get cart => 'Cart';

  @override
  String get orders => 'Orders';

  @override
  String get reservations => 'Reservations';

  @override
  String get profile => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsFollowSystem => 'Follow device language';

  @override
  String get settingsSelected => 'Selected';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsNotifications => 'Notification alerts';

  @override
  String get settingsNotificationsSubtitle =>
      'Show an alert while the app is open. Order updates keep arriving either way.';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get addToCartFailed => 'Could not add to cart. Please try again.';

  @override
  String cartItemLimitReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can add up to $max of this item.',
      many: 'You can add up to $max of this item.',
      few: 'You can add up to $max of this item.',
      two: 'You can add up to 2 of this item.',
      one: 'You can add up to 1 of this item.',
      zero: 'You can add up to 0 of this item.',
    );
    return '$_temp0';
  }

  @override
  String cartLineLimitReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Your cart is full — up to $max different items.',
      many: 'Your cart is full — up to $max different items.',
      few: 'Your cart is full — up to $max different items.',
      two: 'Your cart is full — up to 2 different items.',
      one: 'Your cart is full — up to 1 different item.',
      zero: 'Your cart is full — up to 0 different items.',
    );
    return '$_temp0';
  }

  @override
  String get dishDetails => 'Dish Details';

  @override
  String get itemNotFound => 'Item not found';

  @override
  String get removeFromCart => 'Remove';

  @override
  String get checkout => 'Checkout';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get orderPlaced => 'Order placed successfully!';

  @override
  String get paymentSuccessful => 'Payment successful!';

  @override
  String paymentFailed(String error) {
    return 'Checkout failed: $error';
  }

  @override
  String get deliveryAddress => 'Delivery Address';

  @override
  String get deliveryAddressHint => 'Start typing to auto-complete...';

  @override
  String get deliveryAddressRequired => 'Please enter delivery address';

  @override
  String get promoCode => 'Promo Code';

  @override
  String get promoCodeHint => 'e.g. WELCOME20';

  @override
  String get promoCodeApply => 'Apply';

  @override
  String get promoCodeApplied => 'Promo Code Applied! 5.00 Off';

  @override
  String get promoCodeInvalid => 'Invalid Promo Code';

  @override
  String get subtotal => 'Subtotal:';

  @override
  String get discount => 'Discount:';

  @override
  String get total => 'Total:';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get cancelOrderConfirm =>
      'Are you sure you want to cancel this order?';

  @override
  String get orderCancelled => 'Order cancelled successfully.';

  @override
  String get cancellationExpired => 'Cancellation window has expired.';

  @override
  String get orderStatus_pending => 'Pending';

  @override
  String get orderStatus_confirmed => 'Confirmed';

  @override
  String get orderStatus_preparing => 'Preparing';

  @override
  String get orderStatus_ready => 'Ready for Pickup';

  @override
  String get orderStatus_delivered => 'Delivered';

  @override
  String get orderStatus_cancelled => 'Cancelled';

  @override
  String get outOfStock => 'Out of Stock';

  @override
  String get itemUnavailable => 'This item is currently unavailable.';

  @override
  String get selectBranch => 'Select Branch';

  @override
  String get noNearbyBranches => 'No branches found nearby.';

  @override
  String get outsideDeliveryRadius =>
      'Your location is outside the delivery radius of this branch.';

  @override
  String get locationRequired =>
      'Location access is required to verify delivery radius.';

  @override
  String get updateRequired => 'Update Required';

  @override
  String get updateRequiredMessage =>
      'A new version of the app is required to continue. Please update now to access the app.';

  @override
  String get updateNow => 'Update Now';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get back => 'Back';

  @override
  String get emptyCart => 'Empty Cart';

  @override
  String get deliveryDetails => 'Delivery Details';

  @override
  String get deliveryLocation => 'Delivery Location';

  @override
  String get orderSummary => 'Order Summary';

  @override
  String get setDeliveryLocationFirst =>
      'Please set your delivery location on the map first.';

  @override
  String get taxEstimated => 'Tax (estimated):';

  @override
  String get calculatedAtCheckout => 'Calculated at checkout';

  @override
  String get totalEstimate => 'Total (est.):';

  @override
  String get tooManyTransactions =>
      'Too many recent transactions. Please contact support.';

  @override
  String get ordersTemporarilyPaused =>
      'Orders are temporarily paused. Please try again shortly.';

  @override
  String get taxCouldNotBeCalculated =>
      'Tax could not be calculated. Check your connection and try again.';

  @override
  String get orderSavedOffline =>
      'Order saved offline. It will be submitted when you are back online.';

  @override
  String get orderNotConfirmedRetry =>
      'Order not confirmed. Retrying will not double charge.';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get couldNotLoadOrder =>
      'Could not load this order. Please try again.';

  @override
  String get minimumOrderAmount =>
      'Order total (after promos) must be at least \$0.50 to process a card payment. Please add more items.';

  @override
  String get pleaseSignIn => 'Please sign in to place an order.';

  @override
  String get cartStateInvalid => 'Cart state is invalid. Please try again.';

  @override
  String get pleaseSelectBranch => 'Please select a branch first.';

  @override
  String get branchUnavailable => 'Selected branch is unavailable.';

  @override
  String get orderPlacedSuccessfully =>
      'Your order has been placed successfully!';

  @override
  String get promoApplied => 'Promo applied!';

  @override
  String get promoInvalid => 'Invalid code';

  @override
  String get signInTitle => 'Sign in to continue';

  @override
  String get forgotPasswordQuestion => 'Forgot Password?';

  @override
  String get enterValidEmail => 'Enter valid email';

  @override
  String get minPasswordLength => 'Min 6 characters';

  @override
  String get browseAsGuest => 'Browse as Guest';

  @override
  String get guestAccessUnavailable =>
      'Guest access unavailable. Please sign in.';

  @override
  String resetLinkSent(String email) {
    return 'Reset link sent to $email — check your inbox.';
  }

  @override
  String get couldNotSendReset => 'Could not send reset email.';

  @override
  String get enterEmailForgotPassword =>
      'Enter your email above, then tap Forgot Password.';

  @override
  String get signUpHeader => 'Sign up';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get termsDescription =>
      'Please review our terms of service before using the app.';

  @override
  String get viewTerms => 'View Terms';

  @override
  String get termsUnavailable =>
      'Terms of service are currently unavailable. Please try again later.';

  @override
  String get privacyDescription =>
      'Please review our privacy policy to understand how we handle your data.';

  @override
  String get privacyUnavailable =>
      'Privacy policy is currently unavailable. Please try again later.';

  @override
  String get splashTimeout =>
      'Initialization took too long. Please check your connection and retry.';

  @override
  String get splashInitFailed => 'Initialization failed. Please try again.';

  @override
  String get onboardingWelcome => 'Welcome';

  @override
  String get onboardingDescription =>
      'Order your favorite food, track deliveries, and earn rewards — all in one place.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get yourCart => 'Your Cart';

  @override
  String get retryingPendingSync => 'Retrying pending sync...';

  @override
  String errorLoadingCart(String error) {
    return 'Error loading cart: $error';
  }

  @override
  String get yourCartIsEmpty => 'Your cart is empty';

  @override
  String get noItemsYet => 'Looks like you haven\'t added any items yet.';

  @override
  String get browseMenu => 'Browse Menu';

  @override
  String get proceedToCheckout => 'Proceed to Checkout';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get digitalMenu => 'Digital Menu';

  @override
  String get searchMenu => 'Search menu...';

  @override
  String get all => 'All';

  @override
  String get popular => 'Popular';

  @override
  String get vegan => 'Vegan';

  @override
  String get noItemsMatchCategory => 'No items match this category.';

  @override
  String errorLoadingMenu(String error) {
    return 'Error loading menu: $error';
  }

  @override
  String addedToCart(String item) {
    return '$item added to cart';
  }

  @override
  String soldOut(String item) {
    return '$item is sold out';
  }

  @override
  String get myOrders => 'My Orders';

  @override
  String get unableToLoadOrders => 'Unable to load orders.';

  @override
  String get checkConnectionRetry =>
      'Please check your connection and try again.';

  @override
  String get noOrdersYet => 'No orders yet.';

  @override
  String get hungryPlaceFirstOrder => 'Hungry? Place your first order today!';

  @override
  String get orderNow => 'Order Now';

  @override
  String get reorder => 'Reorder';

  @override
  String get track => 'Track';

  @override
  String get orderCancelledTitle => 'Order Cancelled';

  @override
  String get orderConfirmation_pending => 'Pending';

  @override
  String get orderConfirmation_confirmed => 'Confirmed';

  @override
  String get orderConfirmation_cooking => 'Cooking';

  @override
  String get orderConfirmation_delivered => 'Delivered';

  @override
  String orderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String get timelinePending => 'Pending';

  @override
  String get timelineConfirmed => 'Confirmed';

  @override
  String get timelineCooking => 'Cooking';

  @override
  String get timelineReady => 'Ready';

  @override
  String get orderStatus_pickedUp => 'Picked Up';

  @override
  String get timelineStepPending => 'Pending';

  @override
  String get timelineStepConfirmed => 'Confirmed';

  @override
  String get timelineStepCooking => 'Cooking';

  @override
  String get timelineStepReady => 'Ready';

  @override
  String get timelineStepPickedUp => 'Picked Up';

  @override
  String get adminGateway => 'Admin Gateway';

  @override
  String get gatewayLocked => 'Gateway Locked';

  @override
  String get enterPin => 'Enter your 4-digit staff PIN';

  @override
  String get waitLockout => 'Wait 30 seconds and try again.';

  @override
  String get menuCatalogEditor => 'Menu Catalog Editor';

  @override
  String get noMenuItemsYet => 'No menu items yet.';

  @override
  String get unknownItem => 'Unknown Item';

  @override
  String get generalCategory => 'General';

  @override
  String get termsOfServiceTitle => 'Terms of Service';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String cartIssue(String reasons) {
    return 'Cart issue:\n$reasons';
  }

  @override
  String get cartYouMayAlsoLike => 'You may also like';

  @override
  String get pressHomeToExit => 'Press home button to exit';

  @override
  String get appName => 'Labs';

  @override
  String get categoryPizza => 'Pizza';

  @override
  String get categorySushi => 'Sushi';

  @override
  String get categoryVegan => 'Vegan';

  @override
  String categoryUnderAmount(String amount) {
    return 'Under $amount';
  }

  @override
  String get selectBranchTitle => 'Select a Branch';

  @override
  String get noBranchesAvailable => 'No branches available.';

  @override
  String switchedToBranch(String branch) {
    return 'Switched to $branch';
  }

  @override
  String errorLoadingLoyalty(String error) {
    return 'Error loading loyalty: $error';
  }

  @override
  String get addedToCartNotification => 'Added to Cart!';

  @override
  String get featureFlagsSaved => '✅ Feature flags saved';

  @override
  String get tierAndFeatureFlags => 'Tier & Feature Flags';

  @override
  String get virtualWaitlist => 'Virtual Waitlist';

  @override
  String get waitlistSuccess => 'You are on the waitlist!';

  @override
  String waitlistFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get restaurantSetup => 'Restaurant Setup';

  @override
  String get setupSavedSuccessfully => '✅ Setup saved successfully';

  @override
  String errorSavingSetup(String error) {
    return 'Error saving: $error';
  }

  @override
  String get currencyUSD => 'USD — US Dollar';

  @override
  String get currencyGBP => 'GBP — British Pound';

  @override
  String get currencyEUR => 'EUR — Euro';

  @override
  String get currencyCAD => 'CAD — Canadian Dollar';

  @override
  String get currencyAED => 'AED — UAE Dirham';

  @override
  String get currencySAR => 'SAR — Saudi Riyal';

  @override
  String get deliveryFeeTypeFlat => 'Flat Fee';

  @override
  String get deliveryFeeTypeDistance => 'Distance-Based';

  @override
  String get deliveryFeeTypeFreeAbove => 'Free Above Threshold';

  @override
  String get enableTipPrompt => 'Enable Tip Prompt at Checkout';

  @override
  String get notificationToneTitle =>
      'How should order status notifications sound to customers?';

  @override
  String get toneCasual => 'Casual & Friendly';

  @override
  String get toneCasualSubtitle => '\"Your order is cooking! 🍳\"';

  @override
  String get toneFormal => 'Formal & Professional';

  @override
  String get toneFormalSubtitle =>
      '\"Order Confirmed. Estimated Ready: 20 mins.\"';

  @override
  String get askOnAppLaunch => 'Ask on App Launch';

  @override
  String get askAfterFirstOrder => 'Ask After First Order';

  @override
  String get selectBranchForHours =>
      'Select a branch to edit its operating hours.';

  @override
  String get editOperatingHours => 'Edit Operating Hours';

  @override
  String get operatingHoursSaved => '✅ Operating hours saved';

  @override
  String get holidayModeClosed => 'Holiday Mode (Closed All Day)';

  @override
  String openTime(String time) {
    return 'Open: $time';
  }

  @override
  String closeTime(String time) {
    return 'Close: $time';
  }

  @override
  String get unableToVerifyRole => 'Unable to verify role. Please try again.';

  @override
  String get noAdminPermission => 'No admin permission for this account.';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get viewPrivacyPolicy => 'View Privacy Policy';

  @override
  String get analyticsOverview => 'Analytics Overview';

  @override
  String get manageMenu => 'Manage Menu';

  @override
  String get myProfile => 'My Profile';

  @override
  String get confirmAccountDeletion => 'Confirm Account Deletion';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get ownerOverview => 'Owner Overview';

  @override
  String get allOrders => 'All Orders';

  @override
  String get loadMore => 'Load More';

  @override
  String get noBranchesFound => 'No branches found.';

  @override
  String get noBranchAssigned => '— No branch —';

  @override
  String get defaultBranch => 'Default Branch';

  @override
  String get cannotDeleteBranchWithOrders =>
      'Cannot delete: branch has pending orders.';

  @override
  String get deleteBranchTitle => 'Delete Branch';

  @override
  String get deleteBranchConfirm => 'Are you sure? This cannot be undone.';

  @override
  String get saveBranch => 'Save Branch';

  @override
  String get globalMenu => 'Global Menu';

  @override
  String get available => 'Available';

  @override
  String get kitchenDashboard => 'Kitchen Dashboard';

  @override
  String get startPreparing => 'Start Preparing';

  @override
  String get markReady => 'Mark Ready';

  @override
  String get bookATable => 'Book a Table';

  @override
  String get selectDateTime => 'Please select a date and time.';

  @override
  String get tableBookedSuccessfully => 'Table booked successfully!';

  @override
  String orderTrackerTitle(String id) {
    return 'Order #$id';
  }

  @override
  String get orderCancelledAndRefunded => 'Order Cancelled & Refunded!';

  @override
  String failedToCancel(String error) {
    return 'Failed to cancel: $error';
  }

  @override
  String get arrivalTitle => 'Your order arrived! 🎉';

  @override
  String get howWasExperience => 'How was your experience?';

  @override
  String get submitRating => 'Submit Rating';

  @override
  String get deliveryStatus => 'Delivery Status';

  @override
  String get callingDriver => 'Calling Driver...';

  @override
  String get itemsCopiedToCart => 'Items copied to cart!';

  @override
  String get branchOrders => 'Branch Orders';

  @override
  String get branchMenu => 'Branch Menu';

  @override
  String get imageUploaded => 'Image uploaded!';

  @override
  String get branchReports => 'Branch Reports';

  @override
  String get branchUsers => 'Branch Users';

  @override
  String get driverAssignments => 'Driver Assignments';

  @override
  String get selectDriver => 'Select driver';

  @override
  String get assignDriver => 'Assign Driver';

  @override
  String get orderAssigned => 'Order assigned! Go pick it up.';

  @override
  String authError(String error) {
    return 'Auth Error: $error';
  }

  @override
  String get notSignedIn => 'Not signed in. Use a delivery account.';

  @override
  String get noBranchAssignedContactManager =>
      'No branch assigned. Contact your manager.';

  @override
  String get goLiveGPS => 'Go Live (GPS)';

  @override
  String get navigate => 'Navigate';

  @override
  String get markDelivered => 'Mark Delivered';

  @override
  String get prepareOrder => 'Start Preparing';

  @override
  String get readyOrder => 'Mark Ready';

  @override
  String orderNumberShort(String id) {
    return '#$id';
  }

  @override
  String itemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      many: '$count items',
      few: '$count items',
      two: '2 items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String pendingSyncTooltip(String count) {
    return '$count order(s) pending sync';
  }

  @override
  String get retrySync => 'Retry sync';

  @override
  String get alerts => 'Alerts';

  @override
  String get homeTab => 'Home';

  @override
  String get homeShowcaseTitle => 'Showcase';

  @override
  String get searchTab => 'Search';

  @override
  String get cartTab => 'Cart';

  @override
  String get ordersTab => 'Orders';

  @override
  String get profileTab => 'Profile';

  @override
  String get menuEmpty => 'Menu is empty';

  @override
  String get menuEmptySubtitle =>
      'We are updating our delicious offerings. Check back soon!';

  @override
  String get refresh => 'Refresh';

  @override
  String offlinePendingWrites(String count) {
    return 'Offline • $count pending writes';
  }

  @override
  String get deadLetterQueueTitle => 'Failed syncs';

  @override
  String get deadLetterQueueEmpty =>
      'No failed operations — the queue is healthy.';

  @override
  String get deadLetterQueueDismiss => 'Dismiss';

  @override
  String get deadLetterQueueDismissed => 'Failed operation dismissed.';

  @override
  String get deadLetterQueueView => 'View';

  @override
  String deadLetterQueueRetries(String count) {
    return 'Attempts: $count';
  }

  @override
  String get deadLetterQueueColumnOperation => 'Operation';

  @override
  String get deadLetterQueueColumnReason => 'Reason';

  @override
  String get deadLetterQueueColumnAttempts => 'Attempts';

  @override
  String get deadLetterQueueColumnActions => 'Actions';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get deliveryStatusTitle => 'Delivery Status';

  @override
  String get confirmingOrder => 'Confirming Order...';

  @override
  String get foodReadyWaiting => 'Food is ready! Waiting for driver... 🛵';

  @override
  String get onTheWay => 'On the way! 🛵💨';

  @override
  String get delivered => 'Delivered! 🎉';

  @override
  String get almostThere => 'Almost there, preparing to arrive... 📍';

  @override
  String get arrived => 'Arrived! ✅';

  @override
  String get preparingFood => 'Preparing...';

  @override
  String get calculatingEta => 'Calculating ETA...';

  @override
  String get orderReceived => 'Order\nReceived';

  @override
  String get preparingFoodStep => 'Preparing\nFood';

  @override
  String get onTheWayStep => 'On The\nWay';

  @override
  String get deliveredStep => 'Delivered\n';

  @override
  String get contactDriver => 'Contact Driver';

  @override
  String get contactNotConfigured =>
      'Restaurant contact number is not configured yet.';

  @override
  String get reorderItems => 'Reorder Items';

  @override
  String get yourOrderArrived => 'Your order arrived! 🎉';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get deleteAccountWarning =>
      'This action is permanent. Please enter your credentials to confirm.';

  @override
  String get incorrectCredentials => 'Incorrect credentials. Please try again.';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String versionText(String version, String build, String patchText) {
    return 'Version $version (Build $build)$patchText\nPowered by the app';
  }

  @override
  String pointsLabel(String points) {
    return '$points points';
  }

  @override
  String get maxTier => 'Max Tier';

  @override
  String progressToNextTier(String tier, String points) {
    return 'Progress to $tier ($points pts)';
  }

  @override
  String get maxTierReached => 'You have reached the maximum tier!';

  @override
  String get referFriendEarnPoints => 'Refer a friend, earn 50 points';

  @override
  String get youreInLine => 'You\'re in line!';

  @override
  String get estimatedWaitTime => 'Estimated wait time: 15-20 mins';

  @override
  String get leaveLine => 'Leave Line';

  @override
  String get tableFullJoinLine => 'Table full? Join the virtual line.';

  @override
  String get partySize => 'Party Size:';

  @override
  String get joinWaitlist => 'Join Waitlist';

  @override
  String get kitchenDashboardTitle => 'Kitchen Dashboard';

  @override
  String get preparingTab => 'Preparing';

  @override
  String get readyTab => 'Ready';

  @override
  String get noActiveOrders => 'No active orders';

  @override
  String get noReadyOrders => 'No ready orders';

  @override
  String get signInKitchenAccount =>
      'Please sign in with your kitchen account.';

  @override
  String get failedToLoadBranch =>
      'Failed to load branch. Please contact your manager.';

  @override
  String failedToUpdate(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get editItem => 'Edit Item';

  @override
  String get name => 'Name';

  @override
  String get price => 'Price';

  @override
  String get description => 'Description';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get changeImage => 'Change Image';

  @override
  String get branchStaff => 'Branch Staff';

  @override
  String get deliveryFleet => 'Delivery Fleet';

  @override
  String get noUsersInCategory => 'No users in this category';

  @override
  String get failedToLoadPromotions => 'Could not load promotions.';

  @override
  String get alreadyOnWaitlist =>
      'You are already on the waitlist for this branch.';

  @override
  String get waitlistFull => 'The waitlist is currently full.';

  @override
  String get waitlistJoinFailed =>
      'Could not join the waitlist. Please try again.';

  @override
  String youAreNumberInLine(String position) {
    return 'You are #$position in line';
  }

  @override
  String get authOr => 'or';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authSignInWithApple => 'Sign in with Apple';

  @override
  String get signUpFailed => 'Sign up failed';

  @override
  String get signUpFailedRetry => 'Sign up failed. Please try again.';

  @override
  String orderMinTotal(String amount) {
    return 'Order total must be at least $amount.';
  }

  @override
  String get tipNoTip => 'No Tip';

  @override
  String get tipAddForDriver => 'Add a Tip for Your Driver';

  @override
  String tipOptionLabel(String percent, String amount) {
    return '$percent% ($amount)';
  }

  @override
  String tipSelectedLabel(String amount) {
    return 'Tip: $amount';
  }

  @override
  String setAsRole(String role) {
    return 'Set as $role';
  }

  @override
  String get noUnassignedOrders => 'No unassigned orders';

  @override
  String get activePlan => 'Active Plan';

  @override
  String get tierAutoEnableDescription =>
      'Selecting a tier auto-enables all its included features. You can still toggle individual add-ons below.';

  @override
  String tierFeaturesLabel(String tier) {
    return '$tier Features';
  }

  @override
  String get todaysOrders => 'Today\'s Orders';

  @override
  String get todaysRevenue => 'Today\'s Revenue';

  @override
  String get activeOrders => 'Active Orders';

  @override
  String get overview => 'Overview';

  @override
  String get branches => 'Branches';

  @override
  String get analytics => 'Analytics';

  @override
  String get tiers => 'Tiers';

  @override
  String get bookings => 'Bookings';

  @override
  String get setup => 'Setup';

  @override
  String get ownerUnavailable => 'Owner Unavailable';

  @override
  String get failedToAuthenticateOwner =>
      'Failed to authenticate owner session. Refresh.';

  @override
  String get assignBranch => 'Assign Branch';

  @override
  String get allUsers => 'All Users';

  @override
  String get noBranches => 'No branches found.';

  @override
  String get addBranch => 'Add Branch';

  @override
  String get editBranch => 'Edit Branch';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get pickOnMap => 'Pick on Map';

  @override
  String get deliveryRadiusMiles => 'Delivery Radius (miles)';

  @override
  String get areYouSureCannotBeUndone => 'Are you sure? This cannot be undone.';

  @override
  String get cannotDeleteBranchWithPendingOrders =>
      'Cannot delete: branch has pending orders.';

  @override
  String get restaurantSetupTitle => 'Restaurant Setup';

  @override
  String get saveAll => 'Save All';

  @override
  String get tabBrand => 'Brand';

  @override
  String get tabDelivery => 'Delivery';

  @override
  String get tabLoyalty => 'Loyalty';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get tabSocialLegal => 'Social & Legal';

  @override
  String get tabHours => 'Hours';

  @override
  String get sectionIdentity => 'Identity';

  @override
  String get sectionBranding => 'Branding';

  @override
  String get sectionRegional => 'Regional';

  @override
  String get sectionCompliance => 'Compliance';

  @override
  String get sectionOrderRules => 'Order Rules';

  @override
  String get sectionDeliveryFee => 'Delivery Fee';

  @override
  String get sectionChargesTips => 'Charges & Tips';

  @override
  String get sectionLoyaltyProgram => 'Loyalty Program';

  @override
  String get sectionPointsRules => 'Points Rules';

  @override
  String get sectionMessageTone => 'Message Tone';

  @override
  String get sectionNotificationTiming => 'Permission Prompt Timing';

  @override
  String get sectionSocialMedia => 'Social Media';

  @override
  String get sectionAppStore => 'App Store';

  @override
  String get sectionLegalLinks => 'Legal Links';

  @override
  String get restaurantNameRequired => 'Restaurant Name *';

  @override
  String get hintRestaurantName => 'e.g. Your Kitchen';

  @override
  String get tagline => 'Tagline';

  @override
  String get hintTagline => 'e.g. Fresh. Fast. Flavourful.';

  @override
  String get supportEmail => 'Support Email';

  @override
  String get hintEmail => 'hello@restaurant.com';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get address => 'Address';

  @override
  String get logoUrl => 'Logo URL';

  @override
  String get hintLogoUrl => 'https://cdn.../logo.png';

  @override
  String get heroImageUrl => 'Hero Image URL';

  @override
  String get hintHeroImageUrl => 'https://cdn.../hero.jpg';

  @override
  String get primaryColorHex => 'Primary Color (hex)';

  @override
  String get hintPrimaryColor => '#FF5234';

  @override
  String get secondaryColorHex => 'Secondary Color (hex)';

  @override
  String get hintSecondaryColor => '#1A1A2E';

  @override
  String get currency => 'Currency';

  @override
  String get minimumOrder => 'Minimum Order (\$)';

  @override
  String get avgPrepTime => 'Avg Prep Time (mins)';

  @override
  String get feeStructure => 'Fee Structure';

  @override
  String get deliveryFee => 'Delivery Fee (\$)';

  @override
  String get freeDeliveryAbove => 'Free Delivery Above (\$)';

  @override
  String get serviceCharge => 'Service Charge (%)';

  @override
  String get programName => 'Program Name';

  @override
  String get hintProgramName => 'e.g. Spice Rewards';

  @override
  String get pointsEarnedPerDollar => 'Points Earned Per \$1 Spent';

  @override
  String get pointsNeededToRedeem => 'Points Needed to Redeem';

  @override
  String get rewardValueWhenRedeemed => 'Reward Value When Redeemed (\$)';

  @override
  String get signupBonusPoints => 'Sign-up Bonus Points';

  @override
  String loyaltyPreview(String rate, String threshold, String value) {
    return 'Preview: Customer earns $rate pts per \$1. At $threshold pts they unlock \$$value off.';
  }

  @override
  String get pickLocationOnMap => 'Tap to set delivery location on map';

  @override
  String get instagramUrl => 'Instagram URL';

  @override
  String get tiktokUrl => 'TikTok URL';

  @override
  String get facebookUrl => 'Facebook URL';

  @override
  String get appStoreName => 'App Store Name';

  @override
  String get hintAppStoreName => 'e.g. App — Order & Earn';

  @override
  String get appDescription => 'App Description';

  @override
  String get hintAppDescription => 'Short bio for store listing...';

  @override
  String get termsConditionsUrl => 'Terms & Conditions URL';

  @override
  String get privacyPolicyUrl => 'Privacy Policy URL';

  @override
  String get selectBranchToEditHours =>
      'Select a branch to edit its operating hours.';

  @override
  String get addItem => 'Add Item';

  @override
  String get imageUrl => 'Image URL';

  @override
  String get tagsCommaSeparated => 'Tags (comma-separated, e.g. Spicy, Vegan)';

  @override
  String get acceptingOrders => 'Accepting Orders';

  @override
  String get kitchenPanicMode => 'KITCHEN PANIC MODE';

  @override
  String get storeOpenCheckoutActive => 'Store is open and checkout is active.';

  @override
  String get checkoutsHaltedGlobally =>
      'Incoming checkouts are halted globally.';

  @override
  String get defaultOperatingHours => 'Default Operating Hours';

  @override
  String get holidayModeSubtitle =>
      'Pauses ordering and displays a \"Closed\" banner.';

  @override
  String get mainNavigation => 'Main navigation';

  @override
  String filterByCategory(String category) {
    return 'Filter by $category';
  }

  @override
  String addToCartItem(String item) {
    return 'Add $item to cart';
  }

  @override
  String get loyalty => 'Loyalty';

  @override
  String get loyaltyTier => 'Loyalty Tier';

  @override
  String get points => 'points';

  @override
  String get signInToViewLoyalty => 'Sign in to view your loyalty points';

  @override
  String get waitlist => 'Waitlist';

  @override
  String get tierFlagManager => 'Tier & Flag Manager';

  @override
  String get noFeatureFlagsConfigured => 'No feature flags configured yet.';

  @override
  String get skip => 'Skip';

  @override
  String get tourStep1 =>
      'Browse the menu and explore our delicious offerings.';

  @override
  String get tourStep2 =>
      'Add items to your cart and customize them to your taste.';

  @override
  String get tourStep3 =>
      'Checkout securely and track your order in real time.';

  @override
  String tourStepCounter(String current, String total) {
    return 'Tour Step $current of $total';
  }

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish';

  @override
  String get accountDeletionFailed =>
      'Account deletion failed. Please sign out and try again later.';

  @override
  String accountDeletionFailedWithError(String error) {
    return 'Account deletion failed: $error';
  }

  @override
  String get cannotBeUndone => 'This action cannot be undone.';

  @override
  String get proofOfDeliveryCaptured => 'Proof of delivery captured';

  @override
  String get captureProofOfDeliveryPhoto => 'Capture proof of delivery photo';

  @override
  String get uploading => 'Uploading...';

  @override
  String get captureProofOfDelivery => 'Capture Proof of Delivery';

  @override
  String get tapToAddToCart => 'Tap to add to cart';

  @override
  String get reservationConfirmed => 'Reservation confirmed!';

  @override
  String get reservationNoCapacity => 'No capacity available for this time.';

  @override
  String reservationFailed(String error) {
    return 'Reservation failed: $error';
  }

  @override
  String get reservationRequiresBranch =>
      'Please select a branch before making a reservation.';

  @override
  String get reservationName => 'Name';

  @override
  String get reservationPhone => 'Phone';

  @override
  String get reservationPartySize => 'Party size';

  @override
  String reservationTime(String time) {
    return 'Time: $time';
  }

  @override
  String get reservationNew => 'New Reservation';

  @override
  String get reservationNameRequired => 'Please enter your name';

  @override
  String get reservationPhoneRequired => 'Please enter your phone';

  @override
  String get reservationPartySizeRange => 'Party size must be 1-20';

  @override
  String get reservationPastTime => 'Please select a future date and time.';

  @override
  String get noUpcomingReservations => 'No upcoming reservations.';

  @override
  String guestsCount(String count) {
    return '$count guests';
  }

  @override
  String callCustomer(String name) {
    return 'Call $name';
  }

  @override
  String reservationNotes(String notes) {
    return '📝 $notes';
  }

  @override
  String get joining => 'Joining...';

  @override
  String get partySizeSelector => 'Party size selector';

  @override
  String get locationsTitle => 'Locations';

  @override
  String get couldNotLoadLocations =>
      'Could not load locations. Please try again.';

  @override
  String get noLocationsFound => 'No locations found';

  @override
  String get couldNotGetLocation =>
      'Could not get your location. Tap the map instead.';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get tapMapToSelect => 'Tap on the map to select location';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get loadingLoyalty => 'Loading loyalty';

  @override
  String failedToLoadLoyalty(String error) {
    return 'Failed to load loyalty: $error';
  }

  @override
  String currentTier(String tier) {
    return 'Current tier: $tier';
  }

  @override
  String errorLoadingHome(String error) {
    return 'Error: $error';
  }

  @override
  String get orderHistory => 'Order History';

  @override
  String get loyaltyAndRewards => 'Loyalty & Rewards';

  @override
  String get myReservations => 'My Reservations';

  @override
  String get deleteMyAccount => 'Delete My Account';

  @override
  String get unknownEmail => 'Unknown email';

  @override
  String get exportMyData => 'Export My Data';

  @override
  String get exportMyDataDescription =>
      'Download a copy of all your data — server records and on-device cache (GDPR Art. 20)';

  @override
  String exportDataError(String error) {
    return 'Could not export data: $error';
  }

  @override
  String get exportDataSuccess => 'Your data has been exported and shared.';

  @override
  String get operatingHours => 'Operating Hours';

  @override
  String get operatingHoursSettings => 'Operating Hours Settings';

  @override
  String get loadingOperatingHours => 'Loading operating hours';

  @override
  String get saveOperatingHours => 'Save operating hours';

  @override
  String get savedSuccessfully => 'Saved successfully';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get failedToSave => 'Failed to save';

  @override
  String get saving => 'Saving...';

  @override
  String get closed => 'Closed';

  @override
  String get deliveryDashboardTitle => 'Delivery Dashboard';

  @override
  String get myOrdersTab => 'My Orders';

  @override
  String get availableTab => 'Available';

  @override
  String get noActiveDeliveries => 'No active deliveries';

  @override
  String get gpsLivestreamingMessage => 'GPS livestreaming to your dispatcher';

  @override
  String get navigateToCustomer => 'Navigate to customer';

  @override
  String get readyForPickup => 'Ready for pickup';

  @override
  String get enRoute => 'En route';

  @override
  String get orderAssignedPickup =>
      'Order assigned! Head to the branch for pickup.';

  @override
  String get noOrdersAvailable => 'No orders available';

  @override
  String get assignToMe => 'Assign to me';

  @override
  String get imageUploadFailed => 'Image upload failed';

  @override
  String get revenueLast7Days => 'Revenue — Last 7 Days';

  @override
  String get noRevenueData => 'No revenue data for the last 7 days.';

  @override
  String get topItemsLast7Days => 'Top 5 Items (Last 7 Days)';

  @override
  String get noItemOrdersData => 'No item orders data yet.';

  @override
  String get noItemsData => 'No items data.';

  @override
  String get globalErrorTitle => 'Something went wrong';

  @override
  String get globalErrorBody =>
      'Our team has been notified. Please try refreshing.';

  @override
  String get navHome => 'Home';

  @override
  String get menuAndSearch => 'Menu & Search';

  @override
  String get myCart => 'My Cart';

  @override
  String get findBranch => 'Find a Branch';

  @override
  String tierMember(String tier) {
    return '$tier Member';
  }

  @override
  String get guest => 'Guest';

  @override
  String get gdprTitle => 'Data & Privacy';

  @override
  String gdprBody(String appName) {
    return '$appName uses analytics and push notifications to improve your experience. No personally identifiable data is sold to third parties.\n\nDo you agree to our use of analytics and notifications?';
  }

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get signupAgreePrefix => 'I agree to the';

  @override
  String get signupAgreeAnd => 'and';

  @override
  String get clearLocalLogs => 'Clear local diagnostic logs';

  @override
  String get clearLocalLogsDone => 'Local logs cleared';

  @override
  String forceUpdateBody(String appName) {
    return 'A new version of $appName is required to continue.\nPlease update now to access the app.';
  }

  @override
  String get gracefulErrorBody =>
      'Something went wrong. Please restart the app.';

  @override
  String get restart => 'Restart';

  @override
  String configFallbackScreenTitle(String screenId) {
    return 'Screen: $screenId';
  }

  @override
  String configFallbackScreenBody(String screenId) {
    return 'No widget mapped for $screenId';
  }

  @override
  String get routeErrorTitle => 'Route Error';

  @override
  String routeErrorBody(String error) {
    return 'Navigation error: $error';
  }

  @override
  String pendingSyncCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders pending sync',
      many: '$count orders pending sync',
      few: '$count orders pending sync',
      two: '$count orders pending sync',
      one: '1 order pending sync',
      zero: '$count orders pending sync',
    );
    return '$_temp0';
  }

  @override
  String get loadingCart => 'Loading cart';

  @override
  String get loadingCheckout => 'Loading checkout';

  @override
  String get couldNotLoadOrdersRetry =>
      'Could not load your orders. Please try again.';

  @override
  String orderSemanticsLabel(String token, String status, String total) {
    return 'Order $token, $status, $total';
  }

  @override
  String kitchenOrderItemLine(String name, String quantity) {
    return '• $name × $quantity';
  }

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleKitchen => 'Kitchen';

  @override
  String get roleDelivery => 'Delivery';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get orderStatus_cooking => 'Cooking';

  @override
  String assignBranchFor(String title) {
    return 'Assign Branch — $title';
  }

  @override
  String branchStatusLine(String branch, String status) {
    return '$branch · $status';
  }

  @override
  String roleBranchLine(String role, String branch) {
    return '$role · $branch';
  }

  @override
  String get roleVerificationFailed => 'Role verification failed';

  @override
  String adminRoleLabel(String role) {
    return 'Admin role: $role';
  }

  @override
  String get gatewayAuthError => 'Auth error. Please try again.';

  @override
  String get gatewayRoleVerificationFailed =>
      'Role verification failed. Contact support.';

  @override
  String get gatewayNoAdminAccess => 'You do not have admin access.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get adminDashboardTitle => 'Admin Dashboard';

  @override
  String get lockTtlEnforced => 'Lock TTL enforced';

  @override
  String get enforceLockTtl => 'Enforce Lock TTL';

  @override
  String saveFailedWithError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsSavedSuccessfully => 'Settings saved successfully';

  @override
  String exportShareSubject(String appName) {
    return '$appName Data Export';
  }

  @override
  String exportShareBody(String appName) {
    return 'Here is your data export from $appName.';
  }

  @override
  String get required => 'Required';

  @override
  String get dayMonday => 'Monday';

  @override
  String get dayTuesday => 'Tuesday';

  @override
  String get dayWednesday => 'Wednesday';

  @override
  String get dayThursday => 'Thursday';

  @override
  String get dayFriday => 'Friday';

  @override
  String get daySaturday => 'Saturday';

  @override
  String get daySunday => 'Sunday';

  @override
  String get setupLabelRestaurantName => 'Restaurant Name *';

  @override
  String get setupLabelTagline => 'Tagline';

  @override
  String get setupLabelSupportEmail => 'Support Email';

  @override
  String get setupLabelContactPhone => 'Contact Phone';

  @override
  String get setupLabelAddress => 'Address';

  @override
  String get setupLabelCurrency => 'Currency';

  @override
  String get setupLabelDefaultLanguage => 'Default Language';

  @override
  String get setupLabelMinimumOrderCents => 'Minimum Order (cents)';

  @override
  String get setupLabelDeliveryFeeType => 'Delivery Fee Type';

  @override
  String get setupLabelDeliveryFeeCents => 'Delivery Fee (cents)';

  @override
  String get setupLabelFreeDeliveryThresholdCents =>
      'Free Delivery Threshold (cents)';

  @override
  String get setupLabelEstimatedPrepTimeMinutes =>
      'Estimated Prep Time (minutes)';

  @override
  String get setupLabelServiceChargePercent => 'Service Charge (%)';

  @override
  String get setupLabelLoyaltyProgramName => 'Loyalty Program Name';

  @override
  String get setupLabelPointsPerDollar => 'Points Per Dollar';

  @override
  String get setupLabelRedemptionThresholdPoints =>
      'Redemption Threshold (points)';

  @override
  String get setupLabelRedemptionValueCents => 'Redemption Value (cents)';

  @override
  String get setupLabelSignupBonusPoints => 'Signup Bonus Points';

  @override
  String get setupLabelNotificationTone => 'Notification Tone';

  @override
  String get setupLabelNotificationOptIn => 'Notification Opt-In';

  @override
  String get setupLabelAppStoreName => 'App Store Name';

  @override
  String get setupLabelAppDescription => 'App Description';

  @override
  String get setupLabelTermsUrl => 'Terms URL';

  @override
  String get setupLabelPrivacyUrl => 'Privacy URL';

  @override
  String get setupLabelInstagramUrl => 'Instagram URL';

  @override
  String get setupLabelTiktokUrl => 'TikTok URL';

  @override
  String get setupLabelOpenTimeExample => 'Open Time (e.g. 09:00)';

  @override
  String get setupLabelCloseTimeExample => 'Close Time (e.g. 22:00)';

  @override
  String get mapPickerTitle => 'Set Delivery Location';

  @override
  String get mapPickerConfirm => 'Confirm';

  @override
  String get mapPickerPositioning => 'Positioning...';

  @override
  String get mapPickerMovePin => 'Move the pin to set the delivery location';

  @override
  String get mapPickerLookingUp => 'Looking up address...';

  @override
  String get mapPickerDeliveringTo => 'Delivering to:';

  @override
  String get loadingUserRole => 'Loading user role';

  @override
  String cartItemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cart, $count items',
      many: 'Cart, $count items',
      few: 'Cart, $count items',
      two: 'Cart, 2 items',
      one: 'Cart, 1 item',
      zero: 'Cart, empty',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get deleteBranch => 'Delete branch';

  @override
  String get editMenuItem => 'Edit menu item';

  @override
  String get deleteMenuItem => 'Delete menu item';

  @override
  String get deleteMenuItemConfirm =>
      'Delete this menu item? This action cannot be undone.';

  @override
  String trackerStepOfTotal(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String onboardingPage(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String onboardingPageDot(int page) {
    return 'Page $page';
  }

  @override
  String trackerCurrentStatus(String status) {
    return 'Current status: $status';
  }

  @override
  String get inFlightTitle => 'Please wait';

  @override
  String get inFlightBody =>
      'An action is still in progress. Leaving now could lose your payment result — please wait a moment.';

  @override
  String get removeCartItemTitle => 'Remove this item from your cart?';

  @override
  String get setupLabelTax => 'Tax';

  @override
  String get setupLabelDefaultTaxRate => 'Default tax rate';

  @override
  String get setupLabelState => 'State';

  @override
  String get setupLabelStateRate => 'State tax rate';

  @override
  String get setupAddState => 'Add state rate';

  @override
  String get setupTaxHint =>
      'Percent values are stored per state and used by the server at checkout. Unknown states are rejected — tax is never silently zero.';

  @override
  String get noLocationsHint =>
      'No branches are listed right now — you can browse the menu meanwhile.';

  @override
  String get topDishesToday => 'Top Dishes Today';

  @override
  String get abandonedCarts => 'Abandoned Carts';

  @override
  String get openAnalyticsConsole => 'Open analytics console';

  @override
  String get externalDataDailyNote =>
      'Opens the external analytics console. Reports run once a day — figures are current through yesterday.';

  @override
  String get externalLinkUnavailable =>
      'Could not open the external link. Please try again.';

  @override
  String containsAllergen(String allergen) {
    return 'Contains $allergen';
  }

  @override
  String get allergenNameEggs => 'egg';

  @override
  String get allergenNameMilk => 'milk';

  @override
  String get allergenNameMustard => 'mustard';

  @override
  String get allergenNamePeanuts => 'peanuts';

  @override
  String get allergenNameCrustaceans => 'crustaceans';

  @override
  String get allergenNameMolluscs => 'molluscs';

  @override
  String get allergenNameFish => 'fish';

  @override
  String get allergenNameSesame => 'sesame';

  @override
  String get allergenNameSoybeans => 'soy';

  @override
  String get allergenNameSulphites => 'sulphites';

  @override
  String get allergenNameTreeNuts => 'tree nuts';

  @override
  String get allergenNameWheatTriticale => 'wheat/triticale';

  @override
  String get allergenNameGluten => 'gluten';

  @override
  String get dietaryVegetarian => 'Vegetarian';

  @override
  String get dietaryPescatarian => 'Pescatarian';

  @override
  String get dietaryGlutenFree => 'Gluten-free';

  @override
  String get dietaryDairyFree => 'Dairy-free';

  @override
  String get dietaryNutFree => 'Nut-free';

  @override
  String get dietaryLabel => 'Dietary';

  @override
  String get allergensLabel => 'Allergens';

  @override
  String get hideItemsContaining => 'Hide items containing';

  @override
  String get clearFilters => 'Clear';

  @override
  String get halalCertified => 'Halal certified';

  @override
  String get halalClaimExpired => 'Certification expired';

  @override
  String get dietaryNotesLabel => 'Cross-contamination notes';

  @override
  String get halalCertificationSection => 'Halal certification';

  @override
  String get halalCertBodyLabel => 'Certification body';

  @override
  String get halalCertExpiryLabel => 'Valid until';
}
