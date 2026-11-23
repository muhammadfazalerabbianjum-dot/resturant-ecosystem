import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @firebaseConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Firebase configuration missing - contact the operator'**
  String get firebaseConfigMissing;

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @reservations.
  ///
  /// In en, this message translates to:
  /// **'Reservations'**
  String get reservations;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// UI-15 settings block header
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get settingsFollowSystem;

  /// No description provided for @settingsSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get settingsSelected;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notification alerts'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show an alert while the app is open. Order updates keep arriving either way.'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @addToCartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add to cart. Please try again.'**
  String get addToCartFailed;

  /// No description provided for @cartItemLimitReached.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =0{You can add up to 0 of this item.} =1{You can add up to 1 of this item.} =2{You can add up to 2 of this item.} few{You can add up to {max} of this item.} many{You can add up to {max} of this item.} other{You can add up to {max} of this item.}}'**
  String cartItemLimitReached(int max);

  /// No description provided for @cartLineLimitReached.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =0{Your cart is full — up to 0 different items.} =1{Your cart is full — up to 1 different item.} =2{Your cart is full — up to 2 different items.} few{Your cart is full — up to {max} different items.} many{Your cart is full — up to {max} different items.} other{Your cart is full — up to {max} different items.}}'**
  String cartLineLimitReached(int max);

  /// No description provided for @dishDetails.
  ///
  /// In en, this message translates to:
  /// **'Dish Details'**
  String get dishDetails;

  /// No description provided for @itemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Item not found'**
  String get itemNotFound;

  /// No description provided for @removeFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFromCart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully!'**
  String get orderPlaced;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get paymentSuccessful;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed: {error}'**
  String paymentFailed(String error);

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @deliveryAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Start typing to auto-complete...'**
  String get deliveryAddressHint;

  /// No description provided for @deliveryAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter delivery address'**
  String get deliveryAddressRequired;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCode;

  /// No description provided for @promoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. WELCOME20'**
  String get promoCodeHint;

  /// No description provided for @promoCodeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get promoCodeApply;

  /// No description provided for @promoCodeApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo Code Applied! 5.00 Off'**
  String get promoCodeApplied;

  /// No description provided for @promoCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid Promo Code'**
  String get promoCodeInvalid;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal:'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount:'**
  String get discount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get total;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @cancelOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancelOrderConfirm;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully.'**
  String get orderCancelled;

  /// No description provided for @cancellationExpired.
  ///
  /// In en, this message translates to:
  /// **'Cancellation window has expired.'**
  String get cancellationExpired;

  /// No description provided for @orderStatus_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatus_pending;

  /// No description provided for @orderStatus_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStatus_confirmed;

  /// No description provided for @orderStatus_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get orderStatus_preparing;

  /// No description provided for @orderStatus_ready.
  ///
  /// In en, this message translates to:
  /// **'Ready for Pickup'**
  String get orderStatus_ready;

  /// No description provided for @orderStatus_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatus_delivered;

  /// No description provided for @orderStatus_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatus_cancelled;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @itemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This item is currently unavailable.'**
  String get itemUnavailable;

  /// No description provided for @selectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select Branch'**
  String get selectBranch;

  /// No description provided for @noNearbyBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches found nearby.'**
  String get noNearbyBranches;

  /// No description provided for @outsideDeliveryRadius.
  ///
  /// In en, this message translates to:
  /// **'Your location is outside the delivery radius of this branch.'**
  String get outsideDeliveryRadius;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location access is required to verify delivery radius.'**
  String get locationRequired;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// No description provided for @updateRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'A new version of the app is required to continue. Please update now to access the app.'**
  String get updateRequiredMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Empty Cart'**
  String get emptyCart;

  /// No description provided for @deliveryDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery Details'**
  String get deliveryDetails;

  /// No description provided for @deliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery Location'**
  String get deliveryLocation;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @setDeliveryLocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Please set your delivery location on the map first.'**
  String get setDeliveryLocationFirst;

  /// No description provided for @taxEstimated.
  ///
  /// In en, this message translates to:
  /// **'Tax (estimated):'**
  String get taxEstimated;

  /// No description provided for @calculatedAtCheckout.
  ///
  /// In en, this message translates to:
  /// **'Calculated at checkout'**
  String get calculatedAtCheckout;

  /// No description provided for @totalEstimate.
  ///
  /// In en, this message translates to:
  /// **'Total (est.):'**
  String get totalEstimate;

  /// No description provided for @tooManyTransactions.
  ///
  /// In en, this message translates to:
  /// **'Too many recent transactions. Please contact support.'**
  String get tooManyTransactions;

  /// No description provided for @ordersTemporarilyPaused.
  ///
  /// In en, this message translates to:
  /// **'Orders are temporarily paused. Please try again shortly.'**
  String get ordersTemporarilyPaused;

  /// No description provided for @taxCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'Tax could not be calculated. Check your connection and try again.'**
  String get taxCouldNotBeCalculated;

  /// No description provided for @orderSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Order saved offline. It will be submitted when you are back online.'**
  String get orderSavedOffline;

  /// No description provided for @orderNotConfirmedRetry.
  ///
  /// In en, this message translates to:
  /// **'Order not confirmed. Retrying will not double charge.'**
  String get orderNotConfirmedRetry;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @couldNotLoadOrder.
  ///
  /// In en, this message translates to:
  /// **'Could not load this order. Please try again.'**
  String get couldNotLoadOrder;

  /// No description provided for @minimumOrderAmount.
  ///
  /// In en, this message translates to:
  /// **'Order total (after promos) must be at least \$0.50 to process a card payment. Please add more items.'**
  String get minimumOrderAmount;

  /// No description provided for @pleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to place an order.'**
  String get pleaseSignIn;

  /// No description provided for @cartStateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Cart state is invalid. Please try again.'**
  String get cartStateInvalid;

  /// No description provided for @pleaseSelectBranch.
  ///
  /// In en, this message translates to:
  /// **'Please select a branch first.'**
  String get pleaseSelectBranch;

  /// No description provided for @branchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Selected branch is unavailable.'**
  String get branchUnavailable;

  /// No description provided for @orderPlacedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed successfully!'**
  String get orderPlacedSuccessfully;

  /// No description provided for @promoApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo applied!'**
  String get promoApplied;

  /// No description provided for @promoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get promoInvalid;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInTitle;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get enterValidEmail;

  /// No description provided for @minPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get minPasswordLength;

  /// No description provided for @browseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse as Guest'**
  String get browseAsGuest;

  /// No description provided for @guestAccessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Guest access unavailable. Please sign in.'**
  String get guestAccessUnavailable;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent to {email} — check your inbox.'**
  String resetLinkSent(String email);

  /// No description provided for @couldNotSendReset.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email.'**
  String get couldNotSendReset;

  /// No description provided for @enterEmailForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above, then tap Forgot Password.'**
  String get enterEmailForgotPassword;

  /// No description provided for @signUpHeader.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpHeader;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @termsDescription.
  ///
  /// In en, this message translates to:
  /// **'Please review our terms of service before using the app.'**
  String get termsDescription;

  /// No description provided for @viewTerms.
  ///
  /// In en, this message translates to:
  /// **'View Terms'**
  String get viewTerms;

  /// No description provided for @termsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Terms of service are currently unavailable. Please try again later.'**
  String get termsUnavailable;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Please review our privacy policy to understand how we handle your data.'**
  String get privacyDescription;

  /// No description provided for @privacyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy is currently unavailable. Please try again later.'**
  String get privacyUnavailable;

  /// No description provided for @splashTimeout.
  ///
  /// In en, this message translates to:
  /// **'Initialization took too long. Please check your connection and retry.'**
  String get splashTimeout;

  /// No description provided for @splashInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed. Please try again.'**
  String get splashInitFailed;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingWelcome;

  /// No description provided for @onboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'Order your favorite food, track deliveries, and earn rewards — all in one place.'**
  String get onboardingDescription;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @yourCart.
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get yourCart;

  /// No description provided for @retryingPendingSync.
  ///
  /// In en, this message translates to:
  /// **'Retrying pending sync...'**
  String get retryingPendingSync;

  /// No description provided for @errorLoadingCart.
  ///
  /// In en, this message translates to:
  /// **'Error loading cart: {error}'**
  String errorLoadingCart(String error);

  /// No description provided for @yourCartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get yourCartIsEmpty;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'Looks like you haven\'t added any items yet.'**
  String get noItemsYet;

  /// No description provided for @browseMenu.
  ///
  /// In en, this message translates to:
  /// **'Browse Menu'**
  String get browseMenu;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @digitalMenu.
  ///
  /// In en, this message translates to:
  /// **'Digital Menu'**
  String get digitalMenu;

  /// No description provided for @searchMenu.
  ///
  /// In en, this message translates to:
  /// **'Search menu...'**
  String get searchMenu;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @vegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get vegan;

  /// No description provided for @noItemsMatchCategory.
  ///
  /// In en, this message translates to:
  /// **'No items match this category.'**
  String get noItemsMatchCategory;

  /// No description provided for @errorLoadingMenu.
  ///
  /// In en, this message translates to:
  /// **'Error loading menu: {error}'**
  String errorLoadingMenu(String error);

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{item} added to cart'**
  String addedToCart(String item);

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'{item} is sold out'**
  String soldOut(String item);

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @unableToLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Unable to load orders.'**
  String get unableToLoadOrders;

  /// No description provided for @checkConnectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get checkConnectionRetry;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get noOrdersYet;

  /// No description provided for @hungryPlaceFirstOrder.
  ///
  /// In en, this message translates to:
  /// **'Hungry? Place your first order today!'**
  String get hungryPlaceFirstOrder;

  /// No description provided for @orderNow.
  ///
  /// In en, this message translates to:
  /// **'Order Now'**
  String get orderNow;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @orderCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled'**
  String get orderCancelledTitle;

  /// No description provided for @orderConfirmation_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderConfirmation_pending;

  /// No description provided for @orderConfirmation_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderConfirmation_confirmed;

  /// No description provided for @orderConfirmation_cooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get orderConfirmation_cooking;

  /// No description provided for @orderConfirmation_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderConfirmation_delivered;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(String id);

  /// No description provided for @timelinePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get timelinePending;

  /// No description provided for @timelineConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get timelineConfirmed;

  /// No description provided for @timelineCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get timelineCooking;

  /// No description provided for @timelineReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get timelineReady;

  /// No description provided for @orderStatus_pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get orderStatus_pickedUp;

  /// No description provided for @timelineStepPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get timelineStepPending;

  /// No description provided for @timelineStepConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get timelineStepConfirmed;

  /// No description provided for @timelineStepCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get timelineStepCooking;

  /// No description provided for @timelineStepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get timelineStepReady;

  /// No description provided for @timelineStepPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get timelineStepPickedUp;

  /// No description provided for @adminGateway.
  ///
  /// In en, this message translates to:
  /// **'Admin Gateway'**
  String get adminGateway;

  /// No description provided for @gatewayLocked.
  ///
  /// In en, this message translates to:
  /// **'Gateway Locked'**
  String get gatewayLocked;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit staff PIN'**
  String get enterPin;

  /// No description provided for @waitLockout.
  ///
  /// In en, this message translates to:
  /// **'Wait 30 seconds and try again.'**
  String get waitLockout;

  /// No description provided for @menuCatalogEditor.
  ///
  /// In en, this message translates to:
  /// **'Menu Catalog Editor'**
  String get menuCatalogEditor;

  /// No description provided for @noMenuItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No menu items yet.'**
  String get noMenuItemsYet;

  /// No description provided for @unknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown Item'**
  String get unknownItem;

  /// No description provided for @generalCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalCategory;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceTitle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @cartIssue.
  ///
  /// In en, this message translates to:
  /// **'Cart issue:\n{reasons}'**
  String cartIssue(String reasons);

  /// No description provided for @cartYouMayAlsoLike.
  ///
  /// In en, this message translates to:
  /// **'You may also like'**
  String get cartYouMayAlsoLike;

  /// No description provided for @pressHomeToExit.
  ///
  /// In en, this message translates to:
  /// **'Press home button to exit'**
  String get pressHomeToExit;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get appName;

  /// No description provided for @categoryPizza.
  ///
  /// In en, this message translates to:
  /// **'Pizza'**
  String get categoryPizza;

  /// No description provided for @categorySushi.
  ///
  /// In en, this message translates to:
  /// **'Sushi'**
  String get categorySushi;

  /// No description provided for @categoryVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get categoryVegan;

  /// No description provided for @categoryUnderAmount.
  ///
  /// In en, this message translates to:
  /// **'Under {amount}'**
  String categoryUnderAmount(String amount);

  /// No description provided for @selectBranchTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a Branch'**
  String get selectBranchTitle;

  /// No description provided for @noBranchesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No branches available.'**
  String get noBranchesAvailable;

  /// No description provided for @switchedToBranch.
  ///
  /// In en, this message translates to:
  /// **'Switched to {branch}'**
  String switchedToBranch(String branch);

  /// No description provided for @errorLoadingLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Error loading loyalty: {error}'**
  String errorLoadingLoyalty(String error);

  /// No description provided for @addedToCartNotification.
  ///
  /// In en, this message translates to:
  /// **'Added to Cart!'**
  String get addedToCartNotification;

  /// No description provided for @featureFlagsSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Feature flags saved'**
  String get featureFlagsSaved;

  /// No description provided for @tierAndFeatureFlags.
  ///
  /// In en, this message translates to:
  /// **'Tier & Feature Flags'**
  String get tierAndFeatureFlags;

  /// No description provided for @virtualWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Virtual Waitlist'**
  String get virtualWaitlist;

  /// No description provided for @waitlistSuccess.
  ///
  /// In en, this message translates to:
  /// **'You are on the waitlist!'**
  String get waitlistSuccess;

  /// No description provided for @waitlistFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String waitlistFailed(String error);

  /// No description provided for @restaurantSetup.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Setup'**
  String get restaurantSetup;

  /// No description provided for @setupSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'✅ Setup saved successfully'**
  String get setupSavedSuccessfully;

  /// No description provided for @errorSavingSetup.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String errorSavingSetup(String error);

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'USD — US Dollar'**
  String get currencyUSD;

  /// No description provided for @currencyGBP.
  ///
  /// In en, this message translates to:
  /// **'GBP — British Pound'**
  String get currencyGBP;

  /// No description provided for @currencyEUR.
  ///
  /// In en, this message translates to:
  /// **'EUR — Euro'**
  String get currencyEUR;

  /// No description provided for @currencyCAD.
  ///
  /// In en, this message translates to:
  /// **'CAD — Canadian Dollar'**
  String get currencyCAD;

  /// No description provided for @currencyAED.
  ///
  /// In en, this message translates to:
  /// **'AED — UAE Dirham'**
  String get currencyAED;

  /// No description provided for @currencySAR.
  ///
  /// In en, this message translates to:
  /// **'SAR — Saudi Riyal'**
  String get currencySAR;

  /// No description provided for @deliveryFeeTypeFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat Fee'**
  String get deliveryFeeTypeFlat;

  /// No description provided for @deliveryFeeTypeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance-Based'**
  String get deliveryFeeTypeDistance;

  /// No description provided for @deliveryFeeTypeFreeAbove.
  ///
  /// In en, this message translates to:
  /// **'Free Above Threshold'**
  String get deliveryFeeTypeFreeAbove;

  /// No description provided for @enableTipPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enable Tip Prompt at Checkout'**
  String get enableTipPrompt;

  /// No description provided for @notificationToneTitle.
  ///
  /// In en, this message translates to:
  /// **'How should order status notifications sound to customers?'**
  String get notificationToneTitle;

  /// No description provided for @toneCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual & Friendly'**
  String get toneCasual;

  /// No description provided for @toneCasualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'\"Your order is cooking! 🍳\"'**
  String get toneCasualSubtitle;

  /// No description provided for @toneFormal.
  ///
  /// In en, this message translates to:
  /// **'Formal & Professional'**
  String get toneFormal;

  /// No description provided for @toneFormalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'\"Order Confirmed. Estimated Ready: 20 mins.\"'**
  String get toneFormalSubtitle;

  /// No description provided for @askOnAppLaunch.
  ///
  /// In en, this message translates to:
  /// **'Ask on App Launch'**
  String get askOnAppLaunch;

  /// No description provided for @askAfterFirstOrder.
  ///
  /// In en, this message translates to:
  /// **'Ask After First Order'**
  String get askAfterFirstOrder;

  /// No description provided for @selectBranchForHours.
  ///
  /// In en, this message translates to:
  /// **'Select a branch to edit its operating hours.'**
  String get selectBranchForHours;

  /// No description provided for @editOperatingHours.
  ///
  /// In en, this message translates to:
  /// **'Edit Operating Hours'**
  String get editOperatingHours;

  /// No description provided for @operatingHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Operating hours saved'**
  String get operatingHoursSaved;

  /// No description provided for @holidayModeClosed.
  ///
  /// In en, this message translates to:
  /// **'Holiday Mode (Closed All Day)'**
  String get holidayModeClosed;

  /// No description provided for @openTime.
  ///
  /// In en, this message translates to:
  /// **'Open: {time}'**
  String openTime(String time);

  /// No description provided for @closeTime.
  ///
  /// In en, this message translates to:
  /// **'Close: {time}'**
  String closeTime(String time);

  /// No description provided for @unableToVerifyRole.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify role. Please try again.'**
  String get unableToVerifyRole;

  /// No description provided for @noAdminPermission.
  ///
  /// In en, this message translates to:
  /// **'No admin permission for this account.'**
  String get noAdminPermission;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @viewPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'View Privacy Policy'**
  String get viewPrivacyPolicy;

  /// No description provided for @analyticsOverview.
  ///
  /// In en, this message translates to:
  /// **'Analytics Overview'**
  String get analyticsOverview;

  /// No description provided for @manageMenu.
  ///
  /// In en, this message translates to:
  /// **'Manage Menu'**
  String get manageMenu;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @confirmAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Account Deletion'**
  String get confirmAccountDeletion;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @ownerOverview.
  ///
  /// In en, this message translates to:
  /// **'Owner Overview'**
  String get ownerOverview;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All Orders'**
  String get allOrders;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// No description provided for @noBranchesFound.
  ///
  /// In en, this message translates to:
  /// **'No branches found.'**
  String get noBranchesFound;

  /// No description provided for @noBranchAssigned.
  ///
  /// In en, this message translates to:
  /// **'— No branch —'**
  String get noBranchAssigned;

  /// No description provided for @defaultBranch.
  ///
  /// In en, this message translates to:
  /// **'Default Branch'**
  String get defaultBranch;

  /// No description provided for @cannotDeleteBranchWithOrders.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: branch has pending orders.'**
  String get cannotDeleteBranchWithOrders;

  /// No description provided for @deleteBranchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Branch'**
  String get deleteBranchTitle;

  /// No description provided for @deleteBranchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This cannot be undone.'**
  String get deleteBranchConfirm;

  /// No description provided for @saveBranch.
  ///
  /// In en, this message translates to:
  /// **'Save Branch'**
  String get saveBranch;

  /// No description provided for @globalMenu.
  ///
  /// In en, this message translates to:
  /// **'Global Menu'**
  String get globalMenu;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @kitchenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Dashboard'**
  String get kitchenDashboard;

  /// No description provided for @startPreparing.
  ///
  /// In en, this message translates to:
  /// **'Start Preparing'**
  String get startPreparing;

  /// No description provided for @markReady.
  ///
  /// In en, this message translates to:
  /// **'Mark Ready'**
  String get markReady;

  /// No description provided for @bookATable.
  ///
  /// In en, this message translates to:
  /// **'Book a Table'**
  String get bookATable;

  /// No description provided for @selectDateTime.
  ///
  /// In en, this message translates to:
  /// **'Please select a date and time.'**
  String get selectDateTime;

  /// No description provided for @tableBookedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Table booked successfully!'**
  String get tableBookedSuccessfully;

  /// No description provided for @orderTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderTrackerTitle(String id);

  /// No description provided for @orderCancelledAndRefunded.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled & Refunded!'**
  String get orderCancelledAndRefunded;

  /// No description provided for @failedToCancel.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel: {error}'**
  String failedToCancel(String error);

  /// No description provided for @arrivalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your order arrived! 🎉'**
  String get arrivalTitle;

  /// No description provided for @howWasExperience.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get howWasExperience;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @deliveryStatus.
  ///
  /// In en, this message translates to:
  /// **'Delivery Status'**
  String get deliveryStatus;

  /// No description provided for @callingDriver.
  ///
  /// In en, this message translates to:
  /// **'Calling Driver...'**
  String get callingDriver;

  /// No description provided for @itemsCopiedToCart.
  ///
  /// In en, this message translates to:
  /// **'Items copied to cart!'**
  String get itemsCopiedToCart;

  /// No description provided for @branchOrders.
  ///
  /// In en, this message translates to:
  /// **'Branch Orders'**
  String get branchOrders;

  /// No description provided for @branchMenu.
  ///
  /// In en, this message translates to:
  /// **'Branch Menu'**
  String get branchMenu;

  /// No description provided for @imageUploaded.
  ///
  /// In en, this message translates to:
  /// **'Image uploaded!'**
  String get imageUploaded;

  /// No description provided for @branchReports.
  ///
  /// In en, this message translates to:
  /// **'Branch Reports'**
  String get branchReports;

  /// No description provided for @branchUsers.
  ///
  /// In en, this message translates to:
  /// **'Branch Users'**
  String get branchUsers;

  /// No description provided for @driverAssignments.
  ///
  /// In en, this message translates to:
  /// **'Driver Assignments'**
  String get driverAssignments;

  /// No description provided for @selectDriver.
  ///
  /// In en, this message translates to:
  /// **'Select driver'**
  String get selectDriver;

  /// No description provided for @assignDriver.
  ///
  /// In en, this message translates to:
  /// **'Assign Driver'**
  String get assignDriver;

  /// No description provided for @orderAssigned.
  ///
  /// In en, this message translates to:
  /// **'Order assigned! Go pick it up.'**
  String get orderAssigned;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Auth Error: {error}'**
  String authError(String error);

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in. Use a delivery account.'**
  String get notSignedIn;

  /// No description provided for @noBranchAssignedContactManager.
  ///
  /// In en, this message translates to:
  /// **'No branch assigned. Contact your manager.'**
  String get noBranchAssignedContactManager;

  /// No description provided for @goLiveGPS.
  ///
  /// In en, this message translates to:
  /// **'Go Live (GPS)'**
  String get goLiveGPS;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark Delivered'**
  String get markDelivered;

  /// No description provided for @prepareOrder.
  ///
  /// In en, this message translates to:
  /// **'Start Preparing'**
  String get prepareOrder;

  /// No description provided for @readyOrder.
  ///
  /// In en, this message translates to:
  /// **'Mark Ready'**
  String get readyOrder;

  /// No description provided for @orderNumberShort.
  ///
  /// In en, this message translates to:
  /// **'#{id}'**
  String orderNumberShort(String id);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} =2{2 items} few{{count} items} many{{count} items} other{{count} items}}'**
  String itemsCount(num count);

  /// No description provided for @pendingSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} order(s) pending sync'**
  String pendingSyncTooltip(String count);

  /// No description provided for @retrySync.
  ///
  /// In en, this message translates to:
  /// **'Retry sync'**
  String get retrySync;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @homeShowcaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Showcase'**
  String get homeShowcaseTitle;

  /// No description provided for @searchTab.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTab;

  /// No description provided for @cartTab.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTab;

  /// No description provided for @ordersTab.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @menuEmpty.
  ///
  /// In en, this message translates to:
  /// **'Menu is empty'**
  String get menuEmpty;

  /// No description provided for @menuEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We are updating our delicious offerings. Check back soon!'**
  String get menuEmptySubtitle;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @offlinePendingWrites.
  ///
  /// In en, this message translates to:
  /// **'Offline • {count} pending writes'**
  String offlinePendingWrites(String count);

  /// No description provided for @deadLetterQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed syncs'**
  String get deadLetterQueueTitle;

  /// No description provided for @deadLetterQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No failed operations — the queue is healthy.'**
  String get deadLetterQueueEmpty;

  /// No description provided for @deadLetterQueueDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get deadLetterQueueDismiss;

  /// No description provided for @deadLetterQueueDismissed.
  ///
  /// In en, this message translates to:
  /// **'Failed operation dismissed.'**
  String get deadLetterQueueDismissed;

  /// No description provided for @deadLetterQueueView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get deadLetterQueueView;

  /// No description provided for @deadLetterQueueRetries.
  ///
  /// In en, this message translates to:
  /// **'Attempts: {count}'**
  String deadLetterQueueRetries(String count);

  /// No description provided for @deadLetterQueueColumnOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get deadLetterQueueColumnOperation;

  /// No description provided for @deadLetterQueueColumnReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get deadLetterQueueColumnReason;

  /// No description provided for @deadLetterQueueColumnAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get deadLetterQueueColumnAttempts;

  /// No description provided for @deadLetterQueueColumnActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get deadLetterQueueColumnActions;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @deliveryStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Status'**
  String get deliveryStatusTitle;

  /// No description provided for @confirmingOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirming Order...'**
  String get confirmingOrder;

  /// No description provided for @foodReadyWaiting.
  ///
  /// In en, this message translates to:
  /// **'Food is ready! Waiting for driver... 🛵'**
  String get foodReadyWaiting;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way! 🛵💨'**
  String get onTheWay;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered! 🎉'**
  String get delivered;

  /// No description provided for @almostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there, preparing to arrive... 📍'**
  String get almostThere;

  /// No description provided for @arrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived! ✅'**
  String get arrived;

  /// No description provided for @preparingFood.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparingFood;

  /// No description provided for @calculatingEta.
  ///
  /// In en, this message translates to:
  /// **'Calculating ETA...'**
  String get calculatingEta;

  /// No description provided for @orderReceived.
  ///
  /// In en, this message translates to:
  /// **'Order\nReceived'**
  String get orderReceived;

  /// No description provided for @preparingFoodStep.
  ///
  /// In en, this message translates to:
  /// **'Preparing\nFood'**
  String get preparingFoodStep;

  /// No description provided for @onTheWayStep.
  ///
  /// In en, this message translates to:
  /// **'On The\nWay'**
  String get onTheWayStep;

  /// No description provided for @deliveredStep.
  ///
  /// In en, this message translates to:
  /// **'Delivered\n'**
  String get deliveredStep;

  /// No description provided for @contactDriver.
  ///
  /// In en, this message translates to:
  /// **'Contact Driver'**
  String get contactDriver;

  /// No description provided for @contactNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Restaurant contact number is not configured yet.'**
  String get contactNotConfigured;

  /// No description provided for @reorderItems.
  ///
  /// In en, this message translates to:
  /// **'Reorder Items'**
  String get reorderItems;

  /// No description provided for @yourOrderArrived.
  ///
  /// In en, this message translates to:
  /// **'Your order arrived! 🎉'**
  String get yourOrderArrived;

  /// No description provided for @signOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutTooltip;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. Please enter your credentials to confirm.'**
  String get deleteAccountWarning;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect credentials. Please try again.'**
  String get incorrectCredentials;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// No description provided for @versionText.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (Build {build}){patchText}\nPowered by the app'**
  String versionText(String version, String build, String patchText);

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String pointsLabel(String points);

  /// No description provided for @maxTier.
  ///
  /// In en, this message translates to:
  /// **'Max Tier'**
  String get maxTier;

  /// No description provided for @progressToNextTier.
  ///
  /// In en, this message translates to:
  /// **'Progress to {tier} ({points} pts)'**
  String progressToNextTier(String tier, String points);

  /// No description provided for @maxTierReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached the maximum tier!'**
  String get maxTierReached;

  /// No description provided for @referFriendEarnPoints.
  ///
  /// In en, this message translates to:
  /// **'Refer a friend, earn 50 points'**
  String get referFriendEarnPoints;

  /// No description provided for @youreInLine.
  ///
  /// In en, this message translates to:
  /// **'You\'re in line!'**
  String get youreInLine;

  /// No description provided for @estimatedWaitTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated wait time: 15-20 mins'**
  String get estimatedWaitTime;

  /// No description provided for @leaveLine.
  ///
  /// In en, this message translates to:
  /// **'Leave Line'**
  String get leaveLine;

  /// No description provided for @tableFullJoinLine.
  ///
  /// In en, this message translates to:
  /// **'Table full? Join the virtual line.'**
  String get tableFullJoinLine;

  /// No description provided for @partySize.
  ///
  /// In en, this message translates to:
  /// **'Party Size:'**
  String get partySize;

  /// No description provided for @joinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get joinWaitlist;

  /// No description provided for @kitchenDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Dashboard'**
  String get kitchenDashboardTitle;

  /// No description provided for @preparingTab.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparingTab;

  /// No description provided for @readyTab.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyTab;

  /// No description provided for @noActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'No active orders'**
  String get noActiveOrders;

  /// No description provided for @noReadyOrders.
  ///
  /// In en, this message translates to:
  /// **'No ready orders'**
  String get noReadyOrders;

  /// No description provided for @signInKitchenAccount.
  ///
  /// In en, this message translates to:
  /// **'Please sign in with your kitchen account.'**
  String get signInKitchenAccount;

  /// No description provided for @failedToLoadBranch.
  ///
  /// In en, this message translates to:
  /// **'Failed to load branch. Please contact your manager.'**
  String get failedToLoadBranch;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String failedToUpdate(String error);

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImage;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @branchStaff.
  ///
  /// In en, this message translates to:
  /// **'Branch Staff'**
  String get branchStaff;

  /// No description provided for @deliveryFleet.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fleet'**
  String get deliveryFleet;

  /// No description provided for @noUsersInCategory.
  ///
  /// In en, this message translates to:
  /// **'No users in this category'**
  String get noUsersInCategory;

  /// No description provided for @failedToLoadPromotions.
  ///
  /// In en, this message translates to:
  /// **'Could not load promotions.'**
  String get failedToLoadPromotions;

  /// No description provided for @alreadyOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'You are already on the waitlist for this branch.'**
  String get alreadyOnWaitlist;

  /// No description provided for @waitlistFull.
  ///
  /// In en, this message translates to:
  /// **'The waitlist is currently full.'**
  String get waitlistFull;

  /// No description provided for @waitlistJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join the waitlist. Please try again.'**
  String get waitlistJoinFailed;

  /// No description provided for @youAreNumberInLine.
  ///
  /// In en, this message translates to:
  /// **'You are #{position} in line'**
  String youAreNumberInLine(String position);

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get authSignInWithApple;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get signUpFailed;

  /// No description provided for @signUpFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get signUpFailedRetry;

  /// No description provided for @orderMinTotal.
  ///
  /// In en, this message translates to:
  /// **'Order total must be at least {amount}.'**
  String orderMinTotal(String amount);

  /// No description provided for @tipNoTip.
  ///
  /// In en, this message translates to:
  /// **'No Tip'**
  String get tipNoTip;

  /// No description provided for @tipAddForDriver.
  ///
  /// In en, this message translates to:
  /// **'Add a Tip for Your Driver'**
  String get tipAddForDriver;

  /// No description provided for @tipOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% ({amount})'**
  String tipOptionLabel(String percent, String amount);

  /// No description provided for @tipSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Tip: {amount}'**
  String tipSelectedLabel(String amount);

  /// No description provided for @setAsRole.
  ///
  /// In en, this message translates to:
  /// **'Set as {role}'**
  String setAsRole(String role);

  /// No description provided for @noUnassignedOrders.
  ///
  /// In en, this message translates to:
  /// **'No unassigned orders'**
  String get noUnassignedOrders;

  /// No description provided for @activePlan.
  ///
  /// In en, this message translates to:
  /// **'Active Plan'**
  String get activePlan;

  /// No description provided for @tierAutoEnableDescription.
  ///
  /// In en, this message translates to:
  /// **'Selecting a tier auto-enables all its included features. You can still toggle individual add-ons below.'**
  String get tierAutoEnableDescription;

  /// No description provided for @tierFeaturesLabel.
  ///
  /// In en, this message translates to:
  /// **'{tier} Features'**
  String tierFeaturesLabel(String tier);

  /// No description provided for @todaysOrders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get todaysOrders;

  /// No description provided for @todaysRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todaysRevenue;

  /// No description provided for @activeOrders.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrders;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @tiers.
  ///
  /// In en, this message translates to:
  /// **'Tiers'**
  String get tiers;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @ownerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Owner Unavailable'**
  String get ownerUnavailable;

  /// No description provided for @failedToAuthenticateOwner.
  ///
  /// In en, this message translates to:
  /// **'Failed to authenticate owner session. Refresh.'**
  String get failedToAuthenticateOwner;

  /// No description provided for @assignBranch.
  ///
  /// In en, this message translates to:
  /// **'Assign Branch'**
  String get assignBranch;

  /// No description provided for @allUsers.
  ///
  /// In en, this message translates to:
  /// **'All Users'**
  String get allUsers;

  /// No description provided for @noBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches found.'**
  String get noBranches;

  /// No description provided for @addBranch.
  ///
  /// In en, this message translates to:
  /// **'Add Branch'**
  String get addBranch;

  /// No description provided for @editBranch.
  ///
  /// In en, this message translates to:
  /// **'Edit Branch'**
  String get editBranch;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on Map'**
  String get pickOnMap;

  /// No description provided for @deliveryRadiusMiles.
  ///
  /// In en, this message translates to:
  /// **'Delivery Radius (miles)'**
  String get deliveryRadiusMiles;

  /// No description provided for @areYouSureCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This cannot be undone.'**
  String get areYouSureCannotBeUndone;

  /// No description provided for @cannotDeleteBranchWithPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: branch has pending orders.'**
  String get cannotDeleteBranchWithPendingOrders;

  /// No description provided for @restaurantSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Setup'**
  String get restaurantSetupTitle;

  /// No description provided for @saveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All'**
  String get saveAll;

  /// No description provided for @tabBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get tabBrand;

  /// No description provided for @tabDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get tabDelivery;

  /// No description provided for @tabLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get tabLoyalty;

  /// No description provided for @tabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tabNotifications;

  /// No description provided for @tabSocialLegal.
  ///
  /// In en, this message translates to:
  /// **'Social & Legal'**
  String get tabSocialLegal;

  /// No description provided for @tabHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get tabHours;

  /// No description provided for @sectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get sectionIdentity;

  /// No description provided for @sectionBranding.
  ///
  /// In en, this message translates to:
  /// **'Branding'**
  String get sectionBranding;

  /// No description provided for @sectionRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get sectionRegional;

  /// No description provided for @sectionCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get sectionCompliance;

  /// No description provided for @sectionOrderRules.
  ///
  /// In en, this message translates to:
  /// **'Order Rules'**
  String get sectionOrderRules;

  /// No description provided for @sectionDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get sectionDeliveryFee;

  /// No description provided for @sectionChargesTips.
  ///
  /// In en, this message translates to:
  /// **'Charges & Tips'**
  String get sectionChargesTips;

  /// No description provided for @sectionLoyaltyProgram.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Program'**
  String get sectionLoyaltyProgram;

  /// No description provided for @sectionPointsRules.
  ///
  /// In en, this message translates to:
  /// **'Points Rules'**
  String get sectionPointsRules;

  /// No description provided for @sectionMessageTone.
  ///
  /// In en, this message translates to:
  /// **'Message Tone'**
  String get sectionMessageTone;

  /// No description provided for @sectionNotificationTiming.
  ///
  /// In en, this message translates to:
  /// **'Permission Prompt Timing'**
  String get sectionNotificationTiming;

  /// No description provided for @sectionSocialMedia.
  ///
  /// In en, this message translates to:
  /// **'Social Media'**
  String get sectionSocialMedia;

  /// No description provided for @sectionAppStore.
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get sectionAppStore;

  /// No description provided for @sectionLegalLinks.
  ///
  /// In en, this message translates to:
  /// **'Legal Links'**
  String get sectionLegalLinks;

  /// No description provided for @restaurantNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Name *'**
  String get restaurantNameRequired;

  /// No description provided for @hintRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Your Kitchen'**
  String get hintRestaurantName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get tagline;

  /// No description provided for @hintTagline.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fresh. Fast. Flavourful.'**
  String get hintTagline;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support Email'**
  String get supportEmail;

  /// No description provided for @hintEmail.
  ///
  /// In en, this message translates to:
  /// **'hello@restaurant.com'**
  String get hintEmail;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @logoUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL'**
  String get logoUrl;

  /// No description provided for @hintLogoUrl.
  ///
  /// In en, this message translates to:
  /// **'https://cdn.../logo.png'**
  String get hintLogoUrl;

  /// No description provided for @heroImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Hero Image URL'**
  String get heroImageUrl;

  /// No description provided for @hintHeroImageUrl.
  ///
  /// In en, this message translates to:
  /// **'https://cdn.../hero.jpg'**
  String get hintHeroImageUrl;

  /// No description provided for @primaryColorHex.
  ///
  /// In en, this message translates to:
  /// **'Primary Color (hex)'**
  String get primaryColorHex;

  /// No description provided for @hintPrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'#FF5234'**
  String get hintPrimaryColor;

  /// No description provided for @secondaryColorHex.
  ///
  /// In en, this message translates to:
  /// **'Secondary Color (hex)'**
  String get secondaryColorHex;

  /// No description provided for @hintSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'#1A1A2E'**
  String get hintSecondaryColor;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @minimumOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum Order (\$)'**
  String get minimumOrder;

  /// No description provided for @avgPrepTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Prep Time (mins)'**
  String get avgPrepTime;

  /// No description provided for @feeStructure.
  ///
  /// In en, this message translates to:
  /// **'Fee Structure'**
  String get feeStructure;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee (\$)'**
  String get deliveryFee;

  /// No description provided for @freeDeliveryAbove.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery Above (\$)'**
  String get freeDeliveryAbove;

  /// No description provided for @serviceCharge.
  ///
  /// In en, this message translates to:
  /// **'Service Charge (%)'**
  String get serviceCharge;

  /// No description provided for @programName.
  ///
  /// In en, this message translates to:
  /// **'Program Name'**
  String get programName;

  /// No description provided for @hintProgramName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spice Rewards'**
  String get hintProgramName;

  /// No description provided for @pointsEarnedPerDollar.
  ///
  /// In en, this message translates to:
  /// **'Points Earned Per \$1 Spent'**
  String get pointsEarnedPerDollar;

  /// No description provided for @pointsNeededToRedeem.
  ///
  /// In en, this message translates to:
  /// **'Points Needed to Redeem'**
  String get pointsNeededToRedeem;

  /// No description provided for @rewardValueWhenRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Reward Value When Redeemed (\$)'**
  String get rewardValueWhenRedeemed;

  /// No description provided for @signupBonusPoints.
  ///
  /// In en, this message translates to:
  /// **'Sign-up Bonus Points'**
  String get signupBonusPoints;

  /// No description provided for @loyaltyPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: Customer earns {rate} pts per \$1. At {threshold} pts they unlock \${value} off.'**
  String loyaltyPreview(String rate, String threshold, String value);

  /// No description provided for @pickLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Tap to set delivery location on map'**
  String get pickLocationOnMap;

  /// No description provided for @instagramUrl.
  ///
  /// In en, this message translates to:
  /// **'Instagram URL'**
  String get instagramUrl;

  /// No description provided for @tiktokUrl.
  ///
  /// In en, this message translates to:
  /// **'TikTok URL'**
  String get tiktokUrl;

  /// No description provided for @facebookUrl.
  ///
  /// In en, this message translates to:
  /// **'Facebook URL'**
  String get facebookUrl;

  /// No description provided for @appStoreName.
  ///
  /// In en, this message translates to:
  /// **'App Store Name'**
  String get appStoreName;

  /// No description provided for @hintAppStoreName.
  ///
  /// In en, this message translates to:
  /// **'e.g. App — Order & Earn'**
  String get hintAppStoreName;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'App Description'**
  String get appDescription;

  /// No description provided for @hintAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Short bio for store listing...'**
  String get hintAppDescription;

  /// No description provided for @termsConditionsUrl.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions URL'**
  String get termsConditionsUrl;

  /// No description provided for @privacyPolicyUrl.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy URL'**
  String get privacyPolicyUrl;

  /// No description provided for @selectBranchToEditHours.
  ///
  /// In en, this message translates to:
  /// **'Select a branch to edit its operating hours.'**
  String get selectBranchToEditHours;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @imageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// No description provided for @tagsCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma-separated, e.g. Spicy, Vegan)'**
  String get tagsCommaSeparated;

  /// No description provided for @acceptingOrders.
  ///
  /// In en, this message translates to:
  /// **'Accepting Orders'**
  String get acceptingOrders;

  /// No description provided for @kitchenPanicMode.
  ///
  /// In en, this message translates to:
  /// **'KITCHEN PANIC MODE'**
  String get kitchenPanicMode;

  /// No description provided for @storeOpenCheckoutActive.
  ///
  /// In en, this message translates to:
  /// **'Store is open and checkout is active.'**
  String get storeOpenCheckoutActive;

  /// No description provided for @checkoutsHaltedGlobally.
  ///
  /// In en, this message translates to:
  /// **'Incoming checkouts are halted globally.'**
  String get checkoutsHaltedGlobally;

  /// No description provided for @defaultOperatingHours.
  ///
  /// In en, this message translates to:
  /// **'Default Operating Hours'**
  String get defaultOperatingHours;

  /// No description provided for @holidayModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pauses ordering and displays a \"Closed\" banner.'**
  String get holidayModeSubtitle;

  /// No description provided for @mainNavigation.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get mainNavigation;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by {category}'**
  String filterByCategory(String category);

  /// No description provided for @addToCartItem.
  ///
  /// In en, this message translates to:
  /// **'Add {item} to cart'**
  String addToCartItem(String item);

  /// No description provided for @loyalty.
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get loyalty;

  /// No description provided for @loyaltyTier.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Tier'**
  String get loyaltyTier;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get points;

  /// No description provided for @signInToViewLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your loyalty points'**
  String get signInToViewLoyalty;

  /// No description provided for @waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get waitlist;

  /// No description provided for @tierFlagManager.
  ///
  /// In en, this message translates to:
  /// **'Tier & Flag Manager'**
  String get tierFlagManager;

  /// No description provided for @noFeatureFlagsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No feature flags configured yet.'**
  String get noFeatureFlagsConfigured;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @tourStep1.
  ///
  /// In en, this message translates to:
  /// **'Browse the menu and explore our delicious offerings.'**
  String get tourStep1;

  /// No description provided for @tourStep2.
  ///
  /// In en, this message translates to:
  /// **'Add items to your cart and customize them to your taste.'**
  String get tourStep2;

  /// No description provided for @tourStep3.
  ///
  /// In en, this message translates to:
  /// **'Checkout securely and track your order in real time.'**
  String get tourStep3;

  /// No description provided for @tourStepCounter.
  ///
  /// In en, this message translates to:
  /// **'Tour Step {current} of {total}'**
  String tourStepCounter(String current, String total);

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @accountDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed. Please sign out and try again later.'**
  String get accountDeletionFailed;

  /// No description provided for @accountDeletionFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed: {error}'**
  String accountDeletionFailedWithError(String error);

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @proofOfDeliveryCaptured.
  ///
  /// In en, this message translates to:
  /// **'Proof of delivery captured'**
  String get proofOfDeliveryCaptured;

  /// No description provided for @captureProofOfDeliveryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture proof of delivery photo'**
  String get captureProofOfDeliveryPhoto;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @captureProofOfDelivery.
  ///
  /// In en, this message translates to:
  /// **'Capture Proof of Delivery'**
  String get captureProofOfDelivery;

  /// No description provided for @tapToAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Tap to add to cart'**
  String get tapToAddToCart;

  /// No description provided for @reservationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Reservation confirmed!'**
  String get reservationConfirmed;

  /// No description provided for @reservationNoCapacity.
  ///
  /// In en, this message translates to:
  /// **'No capacity available for this time.'**
  String get reservationNoCapacity;

  /// No description provided for @reservationFailed.
  ///
  /// In en, this message translates to:
  /// **'Reservation failed: {error}'**
  String reservationFailed(String error);

  /// No description provided for @reservationRequiresBranch.
  ///
  /// In en, this message translates to:
  /// **'Please select a branch before making a reservation.'**
  String get reservationRequiresBranch;

  /// No description provided for @reservationName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reservationName;

  /// No description provided for @reservationPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get reservationPhone;

  /// No description provided for @reservationPartySize.
  ///
  /// In en, this message translates to:
  /// **'Party size'**
  String get reservationPartySize;

  /// No description provided for @reservationTime.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String reservationTime(String time);

  /// No description provided for @reservationNew.
  ///
  /// In en, this message translates to:
  /// **'New Reservation'**
  String get reservationNew;

  /// No description provided for @reservationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get reservationNameRequired;

  /// No description provided for @reservationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone'**
  String get reservationPhoneRequired;

  /// No description provided for @reservationPartySizeRange.
  ///
  /// In en, this message translates to:
  /// **'Party size must be 1-20'**
  String get reservationPartySizeRange;

  /// No description provided for @reservationPastTime.
  ///
  /// In en, this message translates to:
  /// **'Please select a future date and time.'**
  String get reservationPastTime;

  /// No description provided for @noUpcomingReservations.
  ///
  /// In en, this message translates to:
  /// **'No upcoming reservations.'**
  String get noUpcomingReservations;

  /// No description provided for @guestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} guests'**
  String guestsCount(String count);

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callCustomer(String name);

  /// No description provided for @reservationNotes.
  ///
  /// In en, this message translates to:
  /// **'📝 {notes}'**
  String reservationNotes(String notes);

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining...'**
  String get joining;

  /// No description provided for @partySizeSelector.
  ///
  /// In en, this message translates to:
  /// **'Party size selector'**
  String get partySizeSelector;

  /// No description provided for @locationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationsTitle;

  /// No description provided for @couldNotLoadLocations.
  ///
  /// In en, this message translates to:
  /// **'Could not load locations. Please try again.'**
  String get couldNotLoadLocations;

  /// No description provided for @noLocationsFound.
  ///
  /// In en, this message translates to:
  /// **'No locations found'**
  String get noLocationsFound;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Tap the map instead.'**
  String get couldNotGetLocation;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @tapMapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to select location'**
  String get tapMapToSelect;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @loadingLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Loading loyalty'**
  String get loadingLoyalty;

  /// No description provided for @failedToLoadLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Failed to load loyalty: {error}'**
  String failedToLoadLoyalty(String error);

  /// No description provided for @currentTier.
  ///
  /// In en, this message translates to:
  /// **'Current tier: {tier}'**
  String currentTier(String tier);

  /// No description provided for @errorLoadingHome.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorLoadingHome(String error);

  /// No description provided for @orderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// No description provided for @loyaltyAndRewards.
  ///
  /// In en, this message translates to:
  /// **'Loyalty & Rewards'**
  String get loyaltyAndRewards;

  /// No description provided for @myReservations.
  ///
  /// In en, this message translates to:
  /// **'My Reservations'**
  String get myReservations;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteMyAccount;

  /// No description provided for @unknownEmail.
  ///
  /// In en, this message translates to:
  /// **'Unknown email'**
  String get unknownEmail;

  /// No description provided for @exportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyData;

  /// No description provided for @exportMyDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Download a copy of all your data — server records and on-device cache (GDPR Art. 20)'**
  String get exportMyDataDescription;

  /// No description provided for @exportDataError.
  ///
  /// In en, this message translates to:
  /// **'Could not export data: {error}'**
  String exportDataError(String error);

  /// No description provided for @exportDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your data has been exported and shared.'**
  String get exportDataSuccess;

  /// No description provided for @operatingHours.
  ///
  /// In en, this message translates to:
  /// **'Operating Hours'**
  String get operatingHours;

  /// No description provided for @operatingHoursSettings.
  ///
  /// In en, this message translates to:
  /// **'Operating Hours Settings'**
  String get operatingHoursSettings;

  /// No description provided for @loadingOperatingHours.
  ///
  /// In en, this message translates to:
  /// **'Loading operating hours'**
  String get loadingOperatingHours;

  /// No description provided for @saveOperatingHours.
  ///
  /// In en, this message translates to:
  /// **'Save operating hours'**
  String get saveOperatingHours;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get savedSuccessfully;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoad;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get failedToSave;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @deliveryDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Dashboard'**
  String get deliveryDashboardTitle;

  /// No description provided for @myOrdersTab.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrdersTab;

  /// No description provided for @availableTab.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableTab;

  /// No description provided for @noActiveDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No active deliveries'**
  String get noActiveDeliveries;

  /// No description provided for @gpsLivestreamingMessage.
  ///
  /// In en, this message translates to:
  /// **'GPS livestreaming to your dispatcher'**
  String get gpsLivestreamingMessage;

  /// No description provided for @navigateToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Navigate to customer'**
  String get navigateToCustomer;

  /// No description provided for @readyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get readyForPickup;

  /// No description provided for @enRoute.
  ///
  /// In en, this message translates to:
  /// **'En route'**
  String get enRoute;

  /// No description provided for @orderAssignedPickup.
  ///
  /// In en, this message translates to:
  /// **'Order assigned! Head to the branch for pickup.'**
  String get orderAssignedPickup;

  /// No description provided for @noOrdersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No orders available'**
  String get noOrdersAvailable;

  /// No description provided for @assignToMe.
  ///
  /// In en, this message translates to:
  /// **'Assign to me'**
  String get assignToMe;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get imageUploadFailed;

  /// No description provided for @revenueLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Revenue — Last 7 Days'**
  String get revenueLast7Days;

  /// No description provided for @noRevenueData.
  ///
  /// In en, this message translates to:
  /// **'No revenue data for the last 7 days.'**
  String get noRevenueData;

  /// No description provided for @topItemsLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Items (Last 7 Days)'**
  String get topItemsLast7Days;

  /// No description provided for @noItemOrdersData.
  ///
  /// In en, this message translates to:
  /// **'No item orders data yet.'**
  String get noItemOrdersData;

  /// No description provided for @noItemsData.
  ///
  /// In en, this message translates to:
  /// **'No items data.'**
  String get noItemsData;

  /// No description provided for @globalErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get globalErrorTitle;

  /// No description provided for @globalErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Our team has been notified. Please try refreshing.'**
  String get globalErrorBody;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @menuAndSearch.
  ///
  /// In en, this message translates to:
  /// **'Menu & Search'**
  String get menuAndSearch;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get myCart;

  /// No description provided for @findBranch.
  ///
  /// In en, this message translates to:
  /// **'Find a Branch'**
  String get findBranch;

  /// No description provided for @tierMember.
  ///
  /// In en, this message translates to:
  /// **'{tier} Member'**
  String tierMember(String tier);

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @gdprTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get gdprTitle;

  /// No description provided for @gdprBody.
  ///
  /// In en, this message translates to:
  /// **'{appName} uses analytics and push notifications to improve your experience. No personally identifiable data is sold to third parties.\n\nDo you agree to our use of analytics and notifications?'**
  String gdprBody(String appName);

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @signupAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get signupAgreePrefix;

  /// No description provided for @signupAgreeAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get signupAgreeAnd;

  /// No description provided for @clearLocalLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear local diagnostic logs'**
  String get clearLocalLogs;

  /// No description provided for @clearLocalLogsDone.
  ///
  /// In en, this message translates to:
  /// **'Local logs cleared'**
  String get clearLocalLogsDone;

  /// No description provided for @forceUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of {appName} is required to continue.\nPlease update now to access the app.'**
  String forceUpdateBody(String appName);

  /// No description provided for @gracefulErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please restart the app.'**
  String get gracefulErrorBody;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @configFallbackScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen: {screenId}'**
  String configFallbackScreenTitle(String screenId);

  /// No description provided for @configFallbackScreenBody.
  ///
  /// In en, this message translates to:
  /// **'No widget mapped for {screenId}'**
  String configFallbackScreenBody(String screenId);

  /// No description provided for @routeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Error'**
  String get routeErrorTitle;

  /// No description provided for @routeErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Navigation error: {error}'**
  String routeErrorBody(String error);

  /// No description provided for @pendingSyncCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{count} orders pending sync} =1{1 order pending sync} =2{{count} orders pending sync} few{{count} orders pending sync} many{{count} orders pending sync} other{{count} orders pending sync}}'**
  String pendingSyncCount(num count);

  /// No description provided for @loadingCart.
  ///
  /// In en, this message translates to:
  /// **'Loading cart'**
  String get loadingCart;

  /// No description provided for @loadingCheckout.
  ///
  /// In en, this message translates to:
  /// **'Loading checkout'**
  String get loadingCheckout;

  /// No description provided for @couldNotLoadOrdersRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load your orders. Please try again.'**
  String get couldNotLoadOrdersRetry;

  /// No description provided for @orderSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Order {token}, {status}, {total}'**
  String orderSemanticsLabel(String token, String status, String total);

  /// No description provided for @kitchenOrderItemLine.
  ///
  /// In en, this message translates to:
  /// **'• {name} × {quantity}'**
  String kitchenOrderItemLine(String name, String quantity);

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get roleKitchen;

  /// No description provided for @roleDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get roleDelivery;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @orderStatus_cooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get orderStatus_cooking;

  /// No description provided for @assignBranchFor.
  ///
  /// In en, this message translates to:
  /// **'Assign Branch — {title}'**
  String assignBranchFor(String title);

  /// No description provided for @branchStatusLine.
  ///
  /// In en, this message translates to:
  /// **'{branch} · {status}'**
  String branchStatusLine(String branch, String status);

  /// No description provided for @roleBranchLine.
  ///
  /// In en, this message translates to:
  /// **'{role} · {branch}'**
  String roleBranchLine(String role, String branch);

  /// No description provided for @roleVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Role verification failed'**
  String get roleVerificationFailed;

  /// No description provided for @adminRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin role: {role}'**
  String adminRoleLabel(String role);

  /// No description provided for @gatewayAuthError.
  ///
  /// In en, this message translates to:
  /// **'Auth error. Please try again.'**
  String get gatewayAuthError;

  /// No description provided for @gatewayRoleVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Role verification failed. Contact support.'**
  String get gatewayRoleVerificationFailed;

  /// No description provided for @gatewayNoAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'You do not have admin access.'**
  String get gatewayNoAdminAccess;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @lockTtlEnforced.
  ///
  /// In en, this message translates to:
  /// **'Lock TTL enforced'**
  String get lockTtlEnforced;

  /// No description provided for @enforceLockTtl.
  ///
  /// In en, this message translates to:
  /// **'Enforce Lock TTL'**
  String get enforceLockTtl;

  /// No description provided for @saveFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailedWithError(String error);

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSavedSuccessfully;

  /// No description provided for @exportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'{appName} Data Export'**
  String exportShareSubject(String appName);

  /// No description provided for @exportShareBody.
  ///
  /// In en, this message translates to:
  /// **'Here is your data export from {appName}.'**
  String exportShareBody(String appName);

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @dayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMonday;

  /// No description provided for @dayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTuesday;

  /// No description provided for @dayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWednesday;

  /// No description provided for @dayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThursday;

  /// No description provided for @dayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFriday;

  /// No description provided for @daySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySaturday;

  /// No description provided for @daySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySunday;

  /// No description provided for @setupLabelRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Name *'**
  String get setupLabelRestaurantName;

  /// No description provided for @setupLabelTagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get setupLabelTagline;

  /// No description provided for @setupLabelSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support Email'**
  String get setupLabelSupportEmail;

  /// No description provided for @setupLabelContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get setupLabelContactPhone;

  /// No description provided for @setupLabelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get setupLabelAddress;

  /// No description provided for @setupLabelCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setupLabelCurrency;

  /// No description provided for @setupLabelDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default Language'**
  String get setupLabelDefaultLanguage;

  /// No description provided for @setupLabelMinimumOrderCents.
  ///
  /// In en, this message translates to:
  /// **'Minimum Order (cents)'**
  String get setupLabelMinimumOrderCents;

  /// No description provided for @setupLabelDeliveryFeeType.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee Type'**
  String get setupLabelDeliveryFeeType;

  /// No description provided for @setupLabelDeliveryFeeCents.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee (cents)'**
  String get setupLabelDeliveryFeeCents;

  /// No description provided for @setupLabelFreeDeliveryThresholdCents.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery Threshold (cents)'**
  String get setupLabelFreeDeliveryThresholdCents;

  /// No description provided for @setupLabelEstimatedPrepTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Estimated Prep Time (minutes)'**
  String get setupLabelEstimatedPrepTimeMinutes;

  /// No description provided for @setupLabelServiceChargePercent.
  ///
  /// In en, this message translates to:
  /// **'Service Charge (%)'**
  String get setupLabelServiceChargePercent;

  /// No description provided for @setupLabelLoyaltyProgramName.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Program Name'**
  String get setupLabelLoyaltyProgramName;

  /// No description provided for @setupLabelPointsPerDollar.
  ///
  /// In en, this message translates to:
  /// **'Points Per Dollar'**
  String get setupLabelPointsPerDollar;

  /// No description provided for @setupLabelRedemptionThresholdPoints.
  ///
  /// In en, this message translates to:
  /// **'Redemption Threshold (points)'**
  String get setupLabelRedemptionThresholdPoints;

  /// No description provided for @setupLabelRedemptionValueCents.
  ///
  /// In en, this message translates to:
  /// **'Redemption Value (cents)'**
  String get setupLabelRedemptionValueCents;

  /// No description provided for @setupLabelSignupBonusPoints.
  ///
  /// In en, this message translates to:
  /// **'Signup Bonus Points'**
  String get setupLabelSignupBonusPoints;

  /// No description provided for @setupLabelNotificationTone.
  ///
  /// In en, this message translates to:
  /// **'Notification Tone'**
  String get setupLabelNotificationTone;

  /// No description provided for @setupLabelNotificationOptIn.
  ///
  /// In en, this message translates to:
  /// **'Notification Opt-In'**
  String get setupLabelNotificationOptIn;

  /// No description provided for @setupLabelAppStoreName.
  ///
  /// In en, this message translates to:
  /// **'App Store Name'**
  String get setupLabelAppStoreName;

  /// No description provided for @setupLabelAppDescription.
  ///
  /// In en, this message translates to:
  /// **'App Description'**
  String get setupLabelAppDescription;

  /// No description provided for @setupLabelTermsUrl.
  ///
  /// In en, this message translates to:
  /// **'Terms URL'**
  String get setupLabelTermsUrl;

  /// No description provided for @setupLabelPrivacyUrl.
  ///
  /// In en, this message translates to:
  /// **'Privacy URL'**
  String get setupLabelPrivacyUrl;

  /// No description provided for @setupLabelInstagramUrl.
  ///
  /// In en, this message translates to:
  /// **'Instagram URL'**
  String get setupLabelInstagramUrl;

  /// No description provided for @setupLabelTiktokUrl.
  ///
  /// In en, this message translates to:
  /// **'TikTok URL'**
  String get setupLabelTiktokUrl;

  /// No description provided for @setupLabelOpenTimeExample.
  ///
  /// In en, this message translates to:
  /// **'Open Time (e.g. 09:00)'**
  String get setupLabelOpenTimeExample;

  /// No description provided for @setupLabelCloseTimeExample.
  ///
  /// In en, this message translates to:
  /// **'Close Time (e.g. 22:00)'**
  String get setupLabelCloseTimeExample;

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Delivery Location'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get mapPickerConfirm;

  /// No description provided for @mapPickerPositioning.
  ///
  /// In en, this message translates to:
  /// **'Positioning...'**
  String get mapPickerPositioning;

  /// No description provided for @mapPickerMovePin.
  ///
  /// In en, this message translates to:
  /// **'Move the pin to set the delivery location'**
  String get mapPickerMovePin;

  /// No description provided for @mapPickerLookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up address...'**
  String get mapPickerLookingUp;

  /// No description provided for @mapPickerDeliveringTo.
  ///
  /// In en, this message translates to:
  /// **'Delivering to:'**
  String get mapPickerDeliveringTo;

  /// No description provided for @loadingUserRole.
  ///
  /// In en, this message translates to:
  /// **'Loading user role'**
  String get loadingUserRole;

  /// No description provided for @cartItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Cart, empty} =1{Cart, 1 item} =2{Cart, 2 items} few{Cart, {count} items} many{Cart, {count} items} other{Cart, {count} items}}'**
  String cartItemsCount(num count);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @deleteBranch.
  ///
  /// In en, this message translates to:
  /// **'Delete branch'**
  String get deleteBranch;

  /// No description provided for @editMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit menu item'**
  String get editMenuItem;

  /// No description provided for @deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete menu item'**
  String get deleteMenuItem;

  /// No description provided for @deleteMenuItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this menu item? This action cannot be undone.'**
  String get deleteMenuItemConfirm;

  /// No description provided for @trackerStepOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String trackerStepOfTotal(int step, int total);

  /// No description provided for @onboardingPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String onboardingPage(int page, int total);

  /// No description provided for @onboardingPageDot.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String onboardingPageDot(int page);

  /// No description provided for @trackerCurrentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current status: {status}'**
  String trackerCurrentStatus(String status);

  /// No description provided for @inFlightTitle.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get inFlightTitle;

  /// No description provided for @inFlightBody.
  ///
  /// In en, this message translates to:
  /// **'An action is still in progress. Leaving now could lose your payment result — please wait a moment.'**
  String get inFlightBody;

  /// No description provided for @removeCartItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this item from your cart?'**
  String get removeCartItemTitle;

  /// No description provided for @setupLabelTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get setupLabelTax;

  /// No description provided for @setupLabelDefaultTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Default tax rate'**
  String get setupLabelDefaultTaxRate;

  /// No description provided for @setupLabelState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get setupLabelState;

  /// No description provided for @setupLabelStateRate.
  ///
  /// In en, this message translates to:
  /// **'State tax rate'**
  String get setupLabelStateRate;

  /// No description provided for @setupAddState.
  ///
  /// In en, this message translates to:
  /// **'Add state rate'**
  String get setupAddState;

  /// No description provided for @setupTaxHint.
  ///
  /// In en, this message translates to:
  /// **'Percent values are stored per state and used by the server at checkout. Unknown states are rejected — tax is never silently zero.'**
  String get setupTaxHint;

  /// No description provided for @noLocationsHint.
  ///
  /// In en, this message translates to:
  /// **'No branches are listed right now — you can browse the menu meanwhile.'**
  String get noLocationsHint;

  /// No description provided for @topDishesToday.
  ///
  /// In en, this message translates to:
  /// **'Top Dishes Today'**
  String get topDishesToday;

  /// No description provided for @abandonedCarts.
  ///
  /// In en, this message translates to:
  /// **'Abandoned Carts'**
  String get abandonedCarts;

  /// No description provided for @openAnalyticsConsole.
  ///
  /// In en, this message translates to:
  /// **'Open analytics console'**
  String get openAnalyticsConsole;

  /// No description provided for @externalDataDailyNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the external analytics console. Reports run once a day — figures are current through yesterday.'**
  String get externalDataDailyNote;

  /// No description provided for @externalLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the external link. Please try again.'**
  String get externalLinkUnavailable;

  /// No description provided for @containsAllergen.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergen}'**
  String containsAllergen(String allergen);

  /// No description provided for @allergenNameEggs.
  ///
  /// In en, this message translates to:
  /// **'egg'**
  String get allergenNameEggs;

  /// No description provided for @allergenNameMilk.
  ///
  /// In en, this message translates to:
  /// **'milk'**
  String get allergenNameMilk;

  /// No description provided for @allergenNameMustard.
  ///
  /// In en, this message translates to:
  /// **'mustard'**
  String get allergenNameMustard;

  /// No description provided for @allergenNamePeanuts.
  ///
  /// In en, this message translates to:
  /// **'peanuts'**
  String get allergenNamePeanuts;

  /// No description provided for @allergenNameCrustaceans.
  ///
  /// In en, this message translates to:
  /// **'crustaceans'**
  String get allergenNameCrustaceans;

  /// No description provided for @allergenNameMolluscs.
  ///
  /// In en, this message translates to:
  /// **'molluscs'**
  String get allergenNameMolluscs;

  /// No description provided for @allergenNameFish.
  ///
  /// In en, this message translates to:
  /// **'fish'**
  String get allergenNameFish;

  /// No description provided for @allergenNameSesame.
  ///
  /// In en, this message translates to:
  /// **'sesame'**
  String get allergenNameSesame;

  /// No description provided for @allergenNameSoybeans.
  ///
  /// In en, this message translates to:
  /// **'soy'**
  String get allergenNameSoybeans;

  /// No description provided for @allergenNameSulphites.
  ///
  /// In en, this message translates to:
  /// **'sulphites'**
  String get allergenNameSulphites;

  /// No description provided for @allergenNameTreeNuts.
  ///
  /// In en, this message translates to:
  /// **'tree nuts'**
  String get allergenNameTreeNuts;

  /// No description provided for @allergenNameWheatTriticale.
  ///
  /// In en, this message translates to:
  /// **'wheat/triticale'**
  String get allergenNameWheatTriticale;

  /// No description provided for @allergenNameGluten.
  ///
  /// In en, this message translates to:
  /// **'gluten'**
  String get allergenNameGluten;

  /// No description provided for @dietaryVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get dietaryVegetarian;

  /// No description provided for @dietaryPescatarian.
  ///
  /// In en, this message translates to:
  /// **'Pescatarian'**
  String get dietaryPescatarian;

  /// No description provided for @dietaryGlutenFree.
  ///
  /// In en, this message translates to:
  /// **'Gluten-free'**
  String get dietaryGlutenFree;

  /// No description provided for @dietaryDairyFree.
  ///
  /// In en, this message translates to:
  /// **'Dairy-free'**
  String get dietaryDairyFree;

  /// No description provided for @dietaryNutFree.
  ///
  /// In en, this message translates to:
  /// **'Nut-free'**
  String get dietaryNutFree;

  /// No description provided for @dietaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Dietary'**
  String get dietaryLabel;

  /// No description provided for @allergensLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergensLabel;

  /// No description provided for @hideItemsContaining.
  ///
  /// In en, this message translates to:
  /// **'Hide items containing'**
  String get hideItemsContaining;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @halalCertified.
  ///
  /// In en, this message translates to:
  /// **'Halal certified'**
  String get halalCertified;

  /// No description provided for @halalClaimExpired.
  ///
  /// In en, this message translates to:
  /// **'Certification expired'**
  String get halalClaimExpired;

  /// No description provided for @dietaryNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Cross-contamination notes'**
  String get dietaryNotesLabel;

  /// No description provided for @halalCertificationSection.
  ///
  /// In en, this message translates to:
  /// **'Halal certification'**
  String get halalCertificationSection;

  /// No description provided for @halalCertBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Certification body'**
  String get halalCertBodyLabel;

  /// No description provided for @halalCertExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get halalCertExpiryLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
