// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get firebaseConfigMissing => 'تكوين Firebase مفقود - تواصل مع المشغّل';

  @override
  String get appTitle => 'Labs';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get menu => 'القائمة';

  @override
  String get cart => 'السلة';

  @override
  String get orders => 'الطلبات';

  @override
  String get reservations => 'الحجوزات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsFollowSystem => 'لغة الجهاز';

  @override
  String get settingsSelected => 'محدد';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsNotifications => 'تنبيهات الإشعارات';

  @override
  String get settingsNotificationsSubtitle =>
      'إظهار تنبيه أثناء فتح التطبيق. تصل تحديثات الطلبات في كل الأحوال.';

  @override
  String get addToCart => 'أضف إلى السلة';

  @override
  String get addToCartFailed =>
      'تعذر إضافة الطبق إلى السلة. يرجى المحاولة مرة أخرى.';

  @override
  String cartItemLimitReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'يمكنك إضافة حتى $max من هذا الطبق.',
      many: 'يمكنك إضافة حتى $max من هذا الطبق.',
      few: 'يمكنك إضافة حتى $max من هذا الطبق.',
      two: 'يمكنك إضافة حتى 2 من هذا الطبق.',
      one: 'يمكنك إضافة حتى 1 من هذا الطبق.',
      zero: 'يمكنك إضافة حتى 0 من هذا الطبق.',
    );
    return '$_temp0';
  }

  @override
  String cartLineLimitReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'سلتك ممتلئة — يُسمح بـ $max عنصرًا مختلفًا كحد أقصى.',
      many: 'سلتك ممتلئة — يُسمح بـ $max عنصرًا مختلفًا كحد أقصى.',
      few: 'سلتك ممتلئة — يُسمح بـ $max عناصر مختلفة كحد أقصى.',
      two: 'سلتك ممتلئة — يُسمح بعنصرين مختلفين كحد أقصى.',
      one: 'سلتك ممتلئة — يُسمح بعنصر مختلف واحد كحد أقصى.',
      zero: 'سلتك ممتلئة — يُسمح بـ 0 عناصر مختلفة كحد أقصى.',
    );
    return '$_temp0';
  }

  @override
  String get dishDetails => 'تفاصيل الطبق';

  @override
  String get itemNotFound => 'الطبق غير موجود';

  @override
  String get removeFromCart => 'إزالة';

  @override
  String get checkout => 'الدفع';

  @override
  String get placeOrder => 'تأكيد الطلب';

  @override
  String get orderPlaced => 'تم تقديم الطلب بنجاح!';

  @override
  String get paymentSuccessful => 'تمت عملية الدفع بنجاح!';

  @override
  String paymentFailed(String error) {
    return 'فشل إتمام الطلب: $error';
  }

  @override
  String get deliveryAddress => 'عنوان التوصيل';

  @override
  String get deliveryAddressHint => 'ابدأ الكتابة للإكمال التلقائي...';

  @override
  String get deliveryAddressRequired => 'يرجى إدخال عنوان التوصيل';

  @override
  String get promoCode => 'كود الخصم';

  @override
  String get promoCodeHint => 'مثال: WELCOME20';

  @override
  String get promoCodeApply => 'تطبيق';

  @override
  String get promoCodeApplied => 'تم تطبيق كود الخصم! خصم 5 دولارات';

  @override
  String get promoCodeInvalid => 'كود الخصم غير صالح';

  @override
  String get subtotal => 'المجموع الفرعي:';

  @override
  String get discount => 'الخصم:';

  @override
  String get total => 'الإجمالي:';

  @override
  String get cancelOrder => 'إلغاء الطلب';

  @override
  String get cancelOrderConfirm => 'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟';

  @override
  String get orderCancelled => 'تم إلغاء الطلب بنجاح.';

  @override
  String get cancellationExpired => 'انتهت مهلة الإلغاء.';

  @override
  String get orderStatus_pending => 'قيد الانتظار';

  @override
  String get orderStatus_confirmed => 'مؤكد';

  @override
  String get orderStatus_preparing => 'قيد التحضير';

  @override
  String get orderStatus_ready => 'جاهز للاستلام';

  @override
  String get orderStatus_delivered => 'تم التوصيل';

  @override
  String get orderStatus_cancelled => 'ملغي';

  @override
  String get outOfStock => 'نفد المخزون';

  @override
  String get itemUnavailable => 'هذا العنصر غير متوفر حالياً.';

  @override
  String get selectBranch => 'اختر الفرع';

  @override
  String get noNearbyBranches => 'لا توجد فروع قريبة.';

  @override
  String get outsideDeliveryRadius => 'موقعك خارج نطاق توصيل هذا الفرع.';

  @override
  String get locationRequired =>
      'يلزم الوصول إلى الموقع للتحقق من نطاق التوصيل.';

  @override
  String get updateRequired => 'تحديث مطلوب';

  @override
  String get updateRequiredMessage =>
      'يلزم وجود إصدار جديد من التطبيق للمتابعة.\nيرجى التحديث الآن للوصول إلى التطبيق.';

  @override
  String get updateNow => 'تحديث الآن';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get back => 'رجوع';

  @override
  String get emptyCart => 'السلة فارغة';

  @override
  String get deliveryDetails => 'تفاصيل التوصيل';

  @override
  String get deliveryLocation => 'موقع التوصيل';

  @override
  String get orderSummary => 'ملخص الطلب';

  @override
  String get setDeliveryLocationFirst =>
      'يرجى تحديد موقع التوصيل على الخريطة أولاً.';

  @override
  String get taxEstimated => 'الضريبة (تقديرية):';

  @override
  String get calculatedAtCheckout => 'تُحسب عند الدفع';

  @override
  String get totalEstimate => 'الإجمالي (تقديري):';

  @override
  String get tooManyTransactions =>
      'عدد المعاملات الأخيرة كبير جداً. يرجى التواصل مع الدعم.';

  @override
  String get ordersTemporarilyPaused =>
      'الطلبات متوقفة مؤقتاً. يرجى المحاولة بعد قليل.';

  @override
  String get taxCouldNotBeCalculated =>
      'تعذّر حساب الضريبة. تحقق من اتصالك وأعد المحاولة.';

  @override
  String get orderSavedOffline =>
      'تم حفظ الطلب دون اتصال. سيُرسل عندما تعود إلى الإنترنت.';

  @override
  String get orderNotConfirmedRetry =>
      'لم يتم تأكيد الطلب. إعادة المحاولة لن تفرض رسوماً مزدوجة.';

  @override
  String get orderNotFound => 'الطلب غير موجود';

  @override
  String get couldNotLoadOrder =>
      'تعذّر تحميل هذا الطلب. يرجى المحاولة مرة أخرى.';

  @override
  String get minimumOrderAmount =>
      'يجب أن يبلغ إجمالي الطلب (بعد الخصومات) ٠٫٥٠ دولاراً على الأقل لمعالجة الدفع بالبطاقة. يرجى إضافة عناصر أخرى.';

  @override
  String get pleaseSignIn => 'يرجى تسجيل الدخول لتقديم الطلب.';

  @override
  String get cartStateInvalid =>
      'حالة السلة غير صالحة. يرجى المحاولة مرة أخرى.';

  @override
  String get pleaseSelectBranch => 'يرجى اختيار الفرع أولاً.';

  @override
  String get branchUnavailable => 'الفرع المحدد غير متاح.';

  @override
  String get orderPlacedSuccessfully => 'تم تقديم طلبك بنجاح!';

  @override
  String get promoApplied => 'تم تطبيق الخصم!';

  @override
  String get promoInvalid => 'كود غير صالح';

  @override
  String get signInTitle => 'سجّل الدخول للمتابعة';

  @override
  String get forgotPasswordQuestion => 'نسيت كلمة المرور؟';

  @override
  String get enterValidEmail => 'أدخل بريداً إلكترونياً صالحاً';

  @override
  String get minPasswordLength => '6 أحرف على الأقل';

  @override
  String get browseAsGuest => 'تصفح كضيف';

  @override
  String get guestAccessUnavailable =>
      'الوصول كضيف غير متاح. يرجى تسجيل الدخول.';

  @override
  String resetLinkSent(String email) {
    return 'تم إرسال رابط إعادة التعيين إلى $email — تحقق من بريدك الوارد.';
  }

  @override
  String get couldNotSendReset => 'تعذر إرسال بريد إعادة التعيين.';

  @override
  String get enterEmailForgotPassword =>
      'أدخل بريدك الإلكتروني أعلاه، ثم اضغط على «نسيت كلمة المرور».';

  @override
  String get signUpHeader => 'إنشاء حساب';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get orContinueWith => 'أو تابع عبر';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get termsDescription => 'يرجى مراجعة شروط الخدمة قبل استخدام التطبيق.';

  @override
  String get viewTerms => 'عرض الشروط';

  @override
  String get termsUnavailable =>
      'شروط الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً.';

  @override
  String get privacyDescription =>
      'يرجى مراجعة سياسة الخصوصية لفهم كيفية تعاملنا مع بياناتك.';

  @override
  String get privacyUnavailable =>
      'سياسة الخصوصية غير متاحة حالياً. يرجى المحاولة لاحقاً.';

  @override
  String get splashTimeout =>
      'استغرق التهيئة وقتاً طويلاً. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';

  @override
  String get splashInitFailed => 'فشلت التهيئة. يرجى المحاولة مرة أخرى.';

  @override
  String get onboardingWelcome => 'مرحباً';

  @override
  String get onboardingDescription =>
      'اطلب طعامك المفضل، وتتبع التوصيل، واكسب المكافآت — كل ذلك في مكان واحد.';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get yourCart => 'سلتك';

  @override
  String get retryingPendingSync => 'إعادة محاولة المزامنة...';

  @override
  String errorLoadingCart(String error) {
    return 'خطأ في تحميل السلة: $error';
  }

  @override
  String get yourCartIsEmpty => 'سلتك فارغة';

  @override
  String get noItemsYet => 'يبدو أنك لم تضف أي عناصر بعد.';

  @override
  String get browseMenu => 'تصفح القائمة';

  @override
  String get proceedToCheckout => 'الانتقال إلى الدفع';

  @override
  String get decreaseQuantity => 'تقليل الكمية';

  @override
  String get increaseQuantity => 'زيادة الكمية';

  @override
  String get digitalMenu => 'القائمة الرقمية';

  @override
  String get searchMenu => 'ابحث في القائمة...';

  @override
  String get all => 'الكل';

  @override
  String get popular => 'الأكثر طلباً';

  @override
  String get vegan => 'نباتي صرف';

  @override
  String get noItemsMatchCategory => 'لا توجد عناصر مطابقة لهذه الفئة.';

  @override
  String errorLoadingMenu(String error) {
    return 'خطأ في تحميل القائمة: $error';
  }

  @override
  String addedToCart(String item) {
    return 'تمت إضافة $item إلى السلة';
  }

  @override
  String soldOut(String item) {
    return '$item نفد مخزونه';
  }

  @override
  String get myOrders => 'طلباتي';

  @override
  String get unableToLoadOrders => 'تعذّر تحميل الطلبات.';

  @override
  String get checkConnectionRetry =>
      'يرجى التحقق من اتصالك والمحاولة مرة أخرى.';

  @override
  String get noOrdersYet => 'لا توجد طلبات بعد.';

  @override
  String get hungryPlaceFirstOrder => 'جائع؟ قدّم طلبك الأول اليوم!';

  @override
  String get orderNow => 'اطلب الآن';

  @override
  String get reorder => 'إعادة الطلب';

  @override
  String get track => 'تتبع';

  @override
  String get orderCancelledTitle => 'تم إلغاء الطلب';

  @override
  String get orderConfirmation_pending => 'قيد الانتظار';

  @override
  String get orderConfirmation_confirmed => 'مؤكد';

  @override
  String get orderConfirmation_cooking => 'قيد التحضير';

  @override
  String get orderConfirmation_delivered => 'تم التوصيل';

  @override
  String orderNumber(String id) {
    return 'الطلب #$id';
  }

  @override
  String get timelinePending => 'قيد الانتظار';

  @override
  String get timelineConfirmed => 'مؤكد';

  @override
  String get timelineCooking => 'قيد التحضير';

  @override
  String get timelineReady => 'جاهز';

  @override
  String get orderStatus_pickedUp => 'تم الاستلام';

  @override
  String get timelineStepPending => 'قيد الانتظار';

  @override
  String get timelineStepConfirmed => 'مؤكد';

  @override
  String get timelineStepCooking => 'قيد التحضير';

  @override
  String get timelineStepReady => 'جاهز';

  @override
  String get timelineStepPickedUp => 'تم الاستلام';

  @override
  String get adminGateway => 'بوابة الإدارة';

  @override
  String get gatewayLocked => 'البوابة مقفلة';

  @override
  String get enterPin => 'أدخل الرمز السري الرباعي للموظف';

  @override
  String get waitLockout => 'انتظر 30 ثانية وحاول مرة أخرى.';

  @override
  String get menuCatalogEditor => 'محرر فهرس القائمة';

  @override
  String get noMenuItemsYet => 'لا توجد عناصر قائمة بعد.';

  @override
  String get unknownItem => 'عنصر غير معروف';

  @override
  String get generalCategory => 'عام';

  @override
  String get termsOfServiceTitle => 'شروط الخدمة';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String cartIssue(String reasons) {
    return 'مشكلة في السلة:\n$reasons';
  }

  @override
  String get cartYouMayAlsoLike => 'قد يعجبك أيضاً';

  @override
  String get pressHomeToExit => 'اضغط زر الرئيسية للخروج';

  @override
  String get appName => 'مختبر';

  @override
  String get categoryPizza => 'بيتزا';

  @override
  String get categorySushi => 'سوشي';

  @override
  String get categoryVegan => 'نباتي';

  @override
  String categoryUnderAmount(String amount) {
    return 'أقل من $amount';
  }

  @override
  String get selectBranchTitle => 'اختر فرعاً';

  @override
  String get noBranchesAvailable => 'لا توجد فروع متاحة.';

  @override
  String switchedToBranch(String branch) {
    return 'تم التبديل إلى $branch';
  }

  @override
  String errorLoadingLoyalty(String error) {
    return 'خطأ في تحميل الولاء: $error';
  }

  @override
  String get addedToCartNotification => 'تمت الإضافة إلى السلة!';

  @override
  String get featureFlagsSaved => '✅ تم حفظ إعدادات الميزات';

  @override
  String get tierAndFeatureFlags => 'المستويات وإعدادات الميزات';

  @override
  String get virtualWaitlist => 'قائمة الانتظار الافتراضية';

  @override
  String get waitlistSuccess => 'أنت الآن في قائمة الانتظار!';

  @override
  String waitlistFailed(String error) {
    return 'فشل: $error';
  }

  @override
  String get restaurantSetup => 'إعداد المطعم';

  @override
  String get setupSavedSuccessfully => '✅ تم حفظ الإعدادات بنجاح';

  @override
  String errorSavingSetup(String error) {
    return 'خطأ في الحفظ: $error';
  }

  @override
  String get currencyUSD => 'دولار أمريكي';

  @override
  String get currencyGBP => 'جنيه إسترليني';

  @override
  String get currencyEUR => 'يورو';

  @override
  String get currencyCAD => 'دولار كندي';

  @override
  String get currencyAED => 'درهم إماراتي';

  @override
  String get currencySAR => 'ريال سعودي';

  @override
  String get deliveryFeeTypeFlat => 'رسوم ثابتة';

  @override
  String get deliveryFeeTypeDistance => 'على أساس المسافة';

  @override
  String get deliveryFeeTypeFreeAbove => 'مجاني فوق الحد';

  @override
  String get enableTipPrompt => 'تمكين مطالبة الإكرامية عند الدفع';

  @override
  String get notificationToneTitle =>
      'كيف يجب أن تُصدر إشعارات حالة الطلب للعملاء؟';

  @override
  String get toneCasual => 'ودود وغير رسمي';

  @override
  String get toneCasualSubtitle => '\"طلبك يُطهى! 🍳\"';

  @override
  String get toneFormal => 'رسمي ومهني';

  @override
  String get toneFormalSubtitle =>
      '\"تم تأكيد الطلب. الوقت المتوقع: 20 دقيقة.\"';

  @override
  String get askOnAppLaunch => 'اسأل عند تشغيل التطبيق';

  @override
  String get askAfterFirstOrder => 'اسأل بعد أول طلب';

  @override
  String get selectBranchForHours => 'اختر فرعاً لتعديل ساعات العمل.';

  @override
  String get editOperatingHours => 'تعديل ساعات العمل';

  @override
  String get operatingHoursSaved => '✅ تم حفظ ساعات العمل';

  @override
  String get holidayModeClosed => 'وضع العطلة (مغلق طوال اليوم)';

  @override
  String openTime(String time) {
    return 'الافتتاح: $time';
  }

  @override
  String closeTime(String time) {
    return 'الإغلاق: $time';
  }

  @override
  String get unableToVerifyRole =>
      'تعذر التحقق من الدور. يرجى المحاولة مرة أخرى.';

  @override
  String get noAdminPermission => 'لا توجد صلاحية إدارية لهذا الحساب.';

  @override
  String get privacyPolicyTitle => 'سياسة الخصوصية';

  @override
  String get viewPrivacyPolicy => 'عرض سياسة الخصوصية';

  @override
  String get analyticsOverview => 'نظرة عامة على التحليلات';

  @override
  String get manageMenu => 'إدارة القائمة';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get confirmAccountDeletion => 'تأكيد حذف الحساب';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get ownerOverview => 'نظرة عامة المالك';

  @override
  String get allOrders => 'جميع الطلبات';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get noBranchesFound => 'لم يتم العثور على فروع.';

  @override
  String get noBranchAssigned => '— لا يوجد فرع —';

  @override
  String get defaultBranch => 'الفرع الافتراضي';

  @override
  String get cannotDeleteBranchWithOrders =>
      'لا يمكن الحذف: الفرع لديه طلبات معلقة.';

  @override
  String get deleteBranchTitle => 'حذف الفرع';

  @override
  String get deleteBranchConfirm => 'هل أنت متأكد؟ لا يمكن التراجع.';

  @override
  String get saveBranch => 'حفظ الفرع';

  @override
  String get globalMenu => 'القائمة العامة';

  @override
  String get available => 'متاح';

  @override
  String get kitchenDashboard => 'لوحة تحكم المطبخ';

  @override
  String get startPreparing => 'بدء التحضير';

  @override
  String get markReady => 'تحديد جاهز';

  @override
  String get bookATable => 'حجز طاولة';

  @override
  String get selectDateTime => 'يرجى تحديد تاريخ ووقت.';

  @override
  String get tableBookedSuccessfully => 'تم حجز الطاولة بنجاح!';

  @override
  String orderTrackerTitle(String id) {
    return 'الطلب #$id';
  }

  @override
  String get orderCancelledAndRefunded => 'تم إلغاء الطلب واسترداد المبلغ!';

  @override
  String failedToCancel(String error) {
    return 'فشل الإلغاء: $error';
  }

  @override
  String get arrivalTitle => 'وصل طلبك! 🎉';

  @override
  String get howWasExperience => 'كيف كانت تجربتك؟';

  @override
  String get submitRating => 'إرسال التقييم';

  @override
  String get deliveryStatus => 'حالة التوصيل';

  @override
  String get callingDriver => 'جارٍ الاتصال بالسائق...';

  @override
  String get itemsCopiedToCart => 'تم نسخ العناصر إلى السلة!';

  @override
  String get branchOrders => 'طلبات الفرع';

  @override
  String get branchMenu => 'قائمة الفرع';

  @override
  String get imageUploaded => 'تم رفع الصورة!';

  @override
  String get branchReports => 'تقارير الفرع';

  @override
  String get branchUsers => 'مستخدمي الفرع';

  @override
  String get driverAssignments => 'توزيعات السائقين';

  @override
  String get selectDriver => 'اختر السائق';

  @override
  String get assignDriver => 'تعيين سائق';

  @override
  String get orderAssigned => 'تم تعيين الطلب! اذهب لاستلامه.';

  @override
  String authError(String error) {
    return 'خطأ في المصادقة: $error';
  }

  @override
  String get notSignedIn => 'غير مسجل الدخول. استخدم حساب توصيل.';

  @override
  String get noBranchAssignedContactManager => 'لا يوجد فرع معين. اتصل بمديرك.';

  @override
  String get goLiveGPS => 'تشغيل تحديد الموقع (GPS)';

  @override
  String get navigate => 'التنقل';

  @override
  String get markDelivered => 'تحديد تم التوصيل';

  @override
  String get prepareOrder => 'بدء التحضير';

  @override
  String get readyOrder => 'تحديد جاهز';

  @override
  String orderNumberShort(String id) {
    return '#$id';
  }

  @override
  String itemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String pendingSyncTooltip(String count) {
    return '$count طلب(طلبات) في انتظار المزامنة';
  }

  @override
  String get retrySync => 'إعادة محاولة المزامنة';

  @override
  String get alerts => 'تنبيهات';

  @override
  String get homeTab => 'الرئيسية';

  @override
  String get homeShowcaseTitle => 'مختارات';

  @override
  String get searchTab => 'بحث';

  @override
  String get cartTab => 'السلة';

  @override
  String get ordersTab => 'الطلبات';

  @override
  String get profileTab => 'الملف الشخصي';

  @override
  String get menuEmpty => 'القائمة فارغة';

  @override
  String get menuEmptySubtitle => 'نحن نحدّث عروضنا اللذيذة. ترقبوا قريباً!';

  @override
  String get refresh => 'تحديث';

  @override
  String offlinePendingWrites(String count) {
    return 'غير متصل • $count عملية معلقة';
  }

  @override
  String get deadLetterQueueTitle => 'المزامنات الفاشلة';

  @override
  String get deadLetterQueueEmpty =>
      'لا توجد عمليات فاشلة — قائمة الانتظار سليمة.';

  @override
  String get deadLetterQueueDismiss => 'تجاهل';

  @override
  String get deadLetterQueueDismissed => 'تم تجاهل العملية الفاشلة.';

  @override
  String get deadLetterQueueView => 'عرض';

  @override
  String deadLetterQueueRetries(String count) {
    return 'عدد المحاولات: $count';
  }

  @override
  String get deadLetterQueueColumnOperation => 'العملية';

  @override
  String get deadLetterQueueColumnReason => 'السبب';

  @override
  String get deadLetterQueueColumnAttempts => 'المحاولات';

  @override
  String get deadLetterQueueColumnActions => 'الإجراءات';

  @override
  String get noItemsFound => 'لم يتم العثور على عناصر';

  @override
  String get deliveryStatusTitle => 'حالة التوصيل';

  @override
  String get confirmingOrder => 'جارٍ تأكيد الطلب...';

  @override
  String get foodReadyWaiting => 'الطعام جاهز! في انتظار السائق... 🛵';

  @override
  String get onTheWay => 'في الطريق! 🛵💨';

  @override
  String get delivered => 'تم التوصيل! 🎉';

  @override
  String get almostThere => 'يكاد يصل، يستعد للوصول... 📍';

  @override
  String get arrived => 'وصل! ✅';

  @override
  String get preparingFood => 'جارٍ التحضير...';

  @override
  String get calculatingEta => 'جارٍ حساب وقت الوصول المتوقع...';

  @override
  String get orderReceived => 'تم استلام\nالطلب';

  @override
  String get preparingFoodStep => 'تحضير\nالطعام';

  @override
  String get onTheWayStep => 'في الطريق';

  @override
  String get deliveredStep => 'تم التوصيل';

  @override
  String get contactDriver => 'الاتصال بالسائق';

  @override
  String get contactNotConfigured => 'رقم تواصل المطعم غير مضبوط بعد.';

  @override
  String get reorderItems => 'إعادة طلب العناصر';

  @override
  String get yourOrderArrived => 'وصل طلبك! 🎉';

  @override
  String get signOutTooltip => 'تسجيل الخروج';

  @override
  String get deleteAccountWarning =>
      'هذا الإجراء دائم. يرجى إدخال بيانات اعتمادك للتأكيد.';

  @override
  String get incorrectCredentials =>
      'بيانات اعتماد غير صحيحة. يرجى المحاولة مرة أخرى.';

  @override
  String get deleteAccountButton => 'حذف الحساب';

  @override
  String versionText(String version, String build, String patchText) {
    return 'الإصدار $version (بناء $build)$patchText\nمدعوم من التطبيق';
  }

  @override
  String pointsLabel(String points) {
    return '$points نقطة';
  }

  @override
  String get maxTier => 'الحد الأقصى للدرجة';

  @override
  String progressToNextTier(String tier, String points) {
    return 'التقدم إلى $tier ($points نقطة)';
  }

  @override
  String get maxTierReached => 'لقد وصلت إلى أعلى درجة!';

  @override
  String get referFriendEarnPoints => 'أحضر صديقاً، احصل على 50 نقطة';

  @override
  String get youreInLine => 'أنت في قائمة الانتظار!';

  @override
  String get estimatedWaitTime => 'وقت الانتظار المتوقع: 15-20 دقيقة';

  @override
  String get leaveLine => 'مغادرة الانتظار';

  @override
  String get tableFullJoinLine =>
      'الطاولة ممتلئة؟ انضم إلى قائمة الانتظار الافتراضية.';

  @override
  String get partySize => 'عدد الأفراد:';

  @override
  String get joinWaitlist => 'انضمام إلى قائمة الانتظار';

  @override
  String get kitchenDashboardTitle => 'لوحة تحكم المطبخ';

  @override
  String get preparingTab => 'قيد التحضير';

  @override
  String get readyTab => 'جاهز';

  @override
  String get noActiveOrders => 'لا توجد طلبات نشطة';

  @override
  String get noReadyOrders => 'لا توجد طلبات جاهزة';

  @override
  String get signInKitchenAccount => 'يرجى تسجيل الدخول بحساب المطبخ الخاص بك.';

  @override
  String get failedToLoadBranch => 'فشل تحميل الفرع. يرجى الاتصال بمديرك.';

  @override
  String failedToUpdate(String error) {
    return 'فشل التحديث: $error';
  }

  @override
  String get editItem => 'تعديل العنصر';

  @override
  String get name => 'الاسم';

  @override
  String get price => 'السعر';

  @override
  String get description => 'الوصف';

  @override
  String get uploadImage => 'رفع صورة';

  @override
  String get changeImage => 'تغيير الصورة';

  @override
  String get branchStaff => 'موظفو الفرع';

  @override
  String get deliveryFleet => 'أسطول التوصيل';

  @override
  String get noUsersInCategory => 'لا يوجد مستخدمون في هذه الفئة';

  @override
  String get failedToLoadPromotions => 'تعذر تحميل العروض.';

  @override
  String get alreadyOnWaitlist => 'أنت بالفعل في قائمة الانتظار لهذا الفرع.';

  @override
  String get waitlistFull => 'قائمة الانتظار ممتلئة حالياً.';

  @override
  String get waitlistJoinFailed =>
      'تعذر الانضمام إلى قائمة الانتظار. حاول مرة أخرى.';

  @override
  String youAreNumberInLine(String position) {
    return 'أنت رقم $position في الطابور';
  }

  @override
  String get authOr => 'أو';

  @override
  String get authSignInWithGoogle => 'تسجيل الدخول باستخدام جوجل';

  @override
  String get authSignInWithApple => 'تسجيل الدخول باستخدام أبل';

  @override
  String get signUpFailed => 'فشل إنشاء الحساب';

  @override
  String get signUpFailedRetry => 'فشل إنشاء الحساب. يرجى المحاولة مرة أخرى.';

  @override
  String orderMinTotal(String amount) {
    return 'يجب أن يكون إجمالي الطلب على الأقل $amount.';
  }

  @override
  String get tipNoTip => 'بدون إكرامية';

  @override
  String get tipAddForDriver => 'أضف إكرامية للسائق';

  @override
  String tipOptionLabel(String percent, String amount) {
    return '$percent٪ ($amount)';
  }

  @override
  String tipSelectedLabel(String amount) {
    return 'الإكرامية: $amount';
  }

  @override
  String setAsRole(String role) {
    return 'تعيين كـ $role';
  }

  @override
  String get noUnassignedOrders => 'لا توجد طلبات غير معينة';

  @override
  String get activePlan => 'الخطة النشطة';

  @override
  String get tierAutoEnableDescription =>
      'اختيار درجة يقوم تلقائياً بتمكين جميع ميزاتها المضمنة. لا يزال بإمكانك تبديل الإضافات الفردية أدناه.';

  @override
  String tierFeaturesLabel(String tier) {
    return 'ميزات $tier';
  }

  @override
  String get todaysOrders => 'طلبات اليوم';

  @override
  String get todaysRevenue => 'إيرادات اليوم';

  @override
  String get activeOrders => 'الطلبات النشطة';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get branches => 'الفروع';

  @override
  String get analytics => 'التحليلات';

  @override
  String get tiers => 'الدرجات';

  @override
  String get bookings => 'الحجوزات';

  @override
  String get setup => 'الإعداد';

  @override
  String get ownerUnavailable => 'المالك غير متاح';

  @override
  String get failedToAuthenticateOwner =>
      'فشل مصادقة جلسة المالك. قم بتحديث الصفحة.';

  @override
  String get assignBranch => 'تعيين الفرع';

  @override
  String get allUsers => 'جميع المستخدمين';

  @override
  String get noBranches => 'لم يتم العثور على فروع.';

  @override
  String get addBranch => 'إضافة فرع';

  @override
  String get editBranch => 'تعديل الفرع';

  @override
  String get latitude => 'خط العرض';

  @override
  String get longitude => 'خط الطول';

  @override
  String get pickOnMap => 'اختيار على الخريطة';

  @override
  String get deliveryRadiusMiles => 'نطاق التوصيل (بالميل)';

  @override
  String get areYouSureCannotBeUndone => 'هل أنت متأكد؟ لا يمكن التراجع.';

  @override
  String get cannotDeleteBranchWithPendingOrders =>
      'لا يمكن الحذف: الفرع لديه طلبات معلقة.';

  @override
  String get restaurantSetupTitle => 'إعداد المطعم';

  @override
  String get saveAll => 'حفظ الكل';

  @override
  String get tabBrand => 'العلامة التجارية';

  @override
  String get tabDelivery => 'التوصيل';

  @override
  String get tabLoyalty => 'الولاء';

  @override
  String get tabNotifications => 'الإشعارات';

  @override
  String get tabSocialLegal => 'وسائل التواصل والقانونية';

  @override
  String get tabHours => 'ساعات العمل';

  @override
  String get sectionIdentity => 'الهوية';

  @override
  String get sectionBranding => 'العلامة التجارية';

  @override
  String get sectionRegional => 'الإقليمي';

  @override
  String get sectionCompliance => 'الامتثال';

  @override
  String get sectionOrderRules => 'قواعد الطلب';

  @override
  String get sectionDeliveryFee => 'رسوم التوصيل';

  @override
  String get sectionChargesTips => 'الرسوم والإكراميات';

  @override
  String get sectionLoyaltyProgram => 'برنامج الولاء';

  @override
  String get sectionPointsRules => 'قواعد النقاط';

  @override
  String get sectionMessageTone => 'نغمة الرسائل';

  @override
  String get sectionNotificationTiming => 'توقيت طلب الإذن';

  @override
  String get sectionSocialMedia => 'وسائل التواصل الاجتماعي';

  @override
  String get sectionAppStore => 'متجر التطبيقات';

  @override
  String get sectionLegalLinks => 'روابط قانونية';

  @override
  String get restaurantNameRequired => 'اسم المطعم *';

  @override
  String get hintRestaurantName => 'مثال: مطبخك';

  @override
  String get tagline => 'الشعار';

  @override
  String get hintTagline => 'مثال: طازج. سريع. لذيذ.';

  @override
  String get supportEmail => 'البريد الإلكتروني للدعم';

  @override
  String get hintEmail => 'hello@restaurant.com';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get address => 'العنوان';

  @override
  String get logoUrl => 'رابط الشعار';

  @override
  String get hintLogoUrl => 'https://cdn.../logo.png';

  @override
  String get heroImageUrl => 'رابط الصورة الرئيسية';

  @override
  String get hintHeroImageUrl => 'https://cdn.../hero.jpg';

  @override
  String get primaryColorHex => 'اللون الأساسي (hex)';

  @override
  String get hintPrimaryColor => '#FF5234';

  @override
  String get secondaryColorHex => 'اللون الثانوي (hex)';

  @override
  String get hintSecondaryColor => '#1A1A2E';

  @override
  String get currency => 'العملة';

  @override
  String get minimumOrder => 'الحد الأدنى للطلب (\$)';

  @override
  String get avgPrepTime => 'متوسط وقت التحضير (دقائق)';

  @override
  String get feeStructure => 'هيكل الرسوم';

  @override
  String get deliveryFee => 'رسوم التوصيل (\$)';

  @override
  String get freeDeliveryAbove => 'توصيل مجاني فوق (\$)';

  @override
  String get serviceCharge => 'رسوم الخدمة (%)';

  @override
  String get programName => 'اسم البرنامج';

  @override
  String get hintProgramName => 'مثال: مكافآت التوابل';

  @override
  String get pointsEarnedPerDollar => 'النقاط المكتسبة لكل \$1 إنفاق';

  @override
  String get pointsNeededToRedeem => 'النقاط المطلوبة للاستبدال';

  @override
  String get rewardValueWhenRedeemed => 'قيمة المكافأة عند الاستبدال (\$)';

  @override
  String get signupBonusPoints => 'نقاط المكافأة عند التسجيل';

  @override
  String loyaltyPreview(String rate, String threshold, String value) {
    return 'معاينة: يكسب العميل $rate نقطة لكل \$1. عند $threshold نقطة، يحصل على خصم \$$value.';
  }

  @override
  String get pickLocationOnMap => 'انقر لتحديد موقع التوصيل على الخريطة';

  @override
  String get instagramUrl => 'رابط إنستغرام';

  @override
  String get tiktokUrl => 'رابط تيك توك';

  @override
  String get facebookUrl => 'رابط فيسبوك';

  @override
  String get appStoreName => 'اسم المتجر';

  @override
  String get hintAppStoreName => 'مثال: التطبيق — اطلب واربح';

  @override
  String get appDescription => 'وصف التطبيق';

  @override
  String get hintAppDescription => 'نبذة قصيرة لقائمة المتجر...';

  @override
  String get termsConditionsUrl => 'رابط الشروط والأحكام';

  @override
  String get privacyPolicyUrl => 'رابط سياسة الخصوصية';

  @override
  String get selectBranchToEditHours => 'اختر فرعاً لتعديل ساعات العمل.';

  @override
  String get addItem => 'إضافة عنصر';

  @override
  String get imageUrl => 'رابط الصورة';

  @override
  String get tagsCommaSeparated => 'العلامات (مفصولة بفواصل، مثل: حار، نباتي)';

  @override
  String get acceptingOrders => 'قبول الطلبات';

  @override
  String get kitchenPanicMode => 'وضع الذعر في المطبخ';

  @override
  String get storeOpenCheckoutActive => 'المتجر مفتوح والدفع نشط.';

  @override
  String get checkoutsHaltedGlobally => 'عمليات الدفع معلقة عالمياً.';

  @override
  String get defaultOperatingHours => 'ساعات العمل الافتراضية';

  @override
  String get holidayModeSubtitle => 'يوقف الطلبات ويعرض لافتة \'مغلق\'.';

  @override
  String get mainNavigation => 'التنقل الرئيسي';

  @override
  String filterByCategory(String category) {
    return 'تصفية حسب $category';
  }

  @override
  String addToCartItem(String item) {
    return 'أضف $item إلى السلة';
  }

  @override
  String get loyalty => 'الولاء';

  @override
  String get loyaltyTier => 'درجة الولاء';

  @override
  String get points => 'نقاط';

  @override
  String get signInToViewLoyalty => 'سجل الدخول لعرض نقاط الولاء الخاصة بك';

  @override
  String get waitlist => 'قائمة الانتظار';

  @override
  String get tierFlagManager => 'مدير الدرجات والعلامات';

  @override
  String get noFeatureFlagsConfigured => 'لا توجد ميزات مفعّلة بعد.';

  @override
  String get skip => 'تخطي';

  @override
  String get tourStep1 => 'تصفح القائمة واستكشف عروضنا اللذيذة.';

  @override
  String get tourStep2 => 'أضف العناصر إلى سلتك وخصصها حسب ذوقك.';

  @override
  String get tourStep3 => 'أكمل الدفع بأمان وتتبع طلبك في الوقت الفعلي.';

  @override
  String tourStepCounter(String current, String total) {
    return 'خطوة الجولة $current من $total';
  }

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get finish => 'إنهاء';

  @override
  String get accountDeletionFailed =>
      'فشل حذف الحساب. يرجى تسجيل الخروج والمحاولة لاحقاً.';

  @override
  String accountDeletionFailedWithError(String error) {
    return 'فشل حذف الحساب: $error';
  }

  @override
  String get cannotBeUndone => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get proofOfDeliveryCaptured => 'تم التقاط إثبات التسليم';

  @override
  String get captureProofOfDeliveryPhoto => 'التقاط صورة إثبات التسليم';

  @override
  String get uploading => 'جارٍ الرفع...';

  @override
  String get captureProofOfDelivery => 'التقاط إثبات التسليم';

  @override
  String get tapToAddToCart => 'انقر للإضافة إلى السلة';

  @override
  String get reservationConfirmed => 'تم تأكيد الحجز!';

  @override
  String get reservationNoCapacity => 'لا توجد سعة متاحة لهذا الوقت.';

  @override
  String reservationFailed(String error) {
    return 'فشل الحجز: $error';
  }

  @override
  String get reservationRequiresBranch => 'يرجى اختيار فرع قبل إجراء الحجز.';

  @override
  String get reservationName => 'الاسم';

  @override
  String get reservationPhone => 'الهاتف';

  @override
  String get reservationPartySize => 'حجم المجموعة';

  @override
  String reservationTime(String time) {
    return 'الوقت: $time';
  }

  @override
  String get reservationNew => 'حجز جديد';

  @override
  String get reservationNameRequired => 'يرجى إدخال اسمك';

  @override
  String get reservationPhoneRequired => 'يرجى إدخال هاتفك';

  @override
  String get reservationPartySizeRange =>
      'يجب أن يكون حجم المجموعة من 1 إلى 20';

  @override
  String get reservationPastTime => 'يرجى اختيار تاريخ ووقت مستقبلي.';

  @override
  String get noUpcomingReservations => 'لا توجد حجوزات قادمة.';

  @override
  String guestsCount(String count) {
    return '$count ضيوف';
  }

  @override
  String callCustomer(String name) {
    return 'اتصال بـ $name';
  }

  @override
  String reservationNotes(String notes) {
    return '📝 $notes';
  }

  @override
  String get joining => 'جارٍ الانضمام...';

  @override
  String get partySizeSelector => 'محدد حجم المجموعة';

  @override
  String get locationsTitle => 'الفروع';

  @override
  String get couldNotLoadLocations =>
      'تعذّر تحميل الفروع. يرجى المحاولة مرة أخرى.';

  @override
  String get noLocationsFound => 'لا توجد فروع';

  @override
  String get couldNotGetLocation =>
      'تعذّر الحصول على موقعك. اضغط على الخريطة بدلاً من ذلك.';

  @override
  String get selectLocation => 'اختر الموقع';

  @override
  String get tapMapToSelect => 'اضغط على الخريطة لاختيار الموقع';

  @override
  String get useMyLocation => 'استخدم موقعي';

  @override
  String get loadingLoyalty => 'جارٍ تحميل الولاء';

  @override
  String failedToLoadLoyalty(String error) {
    return 'فشل تحميل الولاء: $error';
  }

  @override
  String currentTier(String tier) {
    return 'المستوى الحالي: $tier';
  }

  @override
  String errorLoadingHome(String error) {
    return 'خطأ: $error';
  }

  @override
  String get orderHistory => 'الطلبات السابقة';

  @override
  String get loyaltyAndRewards => 'الولاء والمكافآت';

  @override
  String get myReservations => 'حجوزاتي';

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String get unknownEmail => 'بريد إلكتروني غير معروف';

  @override
  String get exportMyData => 'تصدير بياناتي';

  @override
  String get exportMyDataDescription =>
      'تنزيل نسخة من جميع بياناتك — سجلات الخادم وذاكرة التخزين المؤقت على الجهاز (المادة 20 من اللائحة العامة لحماية البيانات)';

  @override
  String exportDataError(String error) {
    return 'تعذّر تصدير البيانات: $error';
  }

  @override
  String get exportDataSuccess => 'تم تصدير بياناتك ومشاركتها.';

  @override
  String get operatingHours => 'ساعات العمل';

  @override
  String get operatingHoursSettings => 'إعدادات ساعات العمل';

  @override
  String get loadingOperatingHours => 'جارٍ تحميل ساعات العمل';

  @override
  String get saveOperatingHours => 'حفظ ساعات العمل';

  @override
  String get savedSuccessfully => 'تم الحفظ بنجاح';

  @override
  String get failedToLoad => 'فشل التحميل';

  @override
  String get failedToSave => 'فشل الحفظ';

  @override
  String get saving => 'جارٍ الحفظ...';

  @override
  String get closed => 'مغلق';

  @override
  String get deliveryDashboardTitle => 'لوحة التوصيل';

  @override
  String get myOrdersTab => 'طلباتي';

  @override
  String get availableTab => 'متاحة';

  @override
  String get noActiveDeliveries => 'لا توجد توصيلات نشطة';

  @override
  String get gpsLivestreamingMessage => 'بث مباشر لموقعك إلى المُوزّع';

  @override
  String get navigateToCustomer => 'التنقل إلى العميل';

  @override
  String get readyForPickup => 'جاهز للاستلام';

  @override
  String get enRoute => 'في الطريق';

  @override
  String get orderAssignedPickup => 'تم تعيين الطلب! توجه إلى الفرع للاستلام.';

  @override
  String get noOrdersAvailable => 'لا توجد طلبات متاحة';

  @override
  String get assignToMe => 'تعيين لي';

  @override
  String get imageUploadFailed => 'فشل رفع الصورة';

  @override
  String get revenueLast7Days => 'الإيرادات — آخر 7 أيام';

  @override
  String get noRevenueData => 'لا توجد بيانات إيرادات لآخر 7 أيام.';

  @override
  String get topItemsLast7Days => 'أفضل 5 عناصر (آخر 7 أيام)';

  @override
  String get noItemOrdersData => 'لا توجد بيانات عناصر حتى الآن.';

  @override
  String get noItemsData => 'لا توجد بيانات عناصر.';

  @override
  String get globalErrorTitle => 'حدث خطأ ما';

  @override
  String get globalErrorBody => 'تم إخطار فريقنا. يرجى محاولة التحديث.';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get menuAndSearch => 'القائمة والبحث';

  @override
  String get myCart => 'سلتي';

  @override
  String get findBranch => 'اعثر على فرع';

  @override
  String tierMember(String tier) {
    return 'عضو $tier';
  }

  @override
  String get guest => 'زائر';

  @override
  String get gdprTitle => 'البيانات والخصوصية';

  @override
  String gdprBody(String appName) {
    return 'يستخدم $appName التحليلات والإشعارات لتحسين تجربتك. لا يتم بيع أي بيانات شخصية يمكن التعرف عليها لأطراف ثالثة.\n\nهل توافق على استخدامنا للتحليلات والإشعارات؟';
  }

  @override
  String get decline => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get signupAgreePrefix => 'أوافق على';

  @override
  String get signupAgreeAnd => 'و';

  @override
  String get clearLocalLogs => 'محو سجلات التشخيص المحلية';

  @override
  String get clearLocalLogsDone => 'تم محو السجلات المحلية';

  @override
  String forceUpdateBody(String appName) {
    return 'الإصدار الجديد من $appName مطلوب للمتابعة.\nيرجى التحديث الآن للوصول إلى التطبيق.';
  }

  @override
  String get gracefulErrorBody => 'حدث خطأ ما. يرجى إعادة تشغيل التطبيق.';

  @override
  String get restart => 'إعادة التشغيل';

  @override
  String configFallbackScreenTitle(String screenId) {
    return 'الشاشة: $screenId';
  }

  @override
  String configFallbackScreenBody(String screenId) {
    return 'لا توجد واجهة مرتبطة بـ $screenId';
  }

  @override
  String get routeErrorTitle => 'خطأ في التوجيه';

  @override
  String routeErrorBody(String error) {
    return 'خطأ في التنقل: $error';
  }

  @override
  String pendingSyncCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب في انتظار المزامنة',
      many: '$count طلبًا في انتظار المزامنة',
      few: '$count طلبات في انتظار المزامنة',
      two: 'طلبان في انتظار المزامنة',
      one: 'طلب واحد في انتظار المزامنة',
      zero: 'لا طلبات في انتظار المزامنة',
    );
    return '$_temp0';
  }

  @override
  String get loadingCart => 'جارٍ تحميل السلة';

  @override
  String get loadingCheckout => 'جارٍ تحميل الدفع';

  @override
  String get couldNotLoadOrdersRetry =>
      'تعذر تحميل طلباتك. يرجى المحاولة مرة أخرى.';

  @override
  String orderSemanticsLabel(String token, String status, String total) {
    return 'الطلب $token، $status، $total';
  }

  @override
  String kitchenOrderItemLine(String name, String quantity) {
    return '• $name × $quantity';
  }

  @override
  String get roleOwner => 'مالك';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleKitchen => 'المطبخ';

  @override
  String get roleDelivery => 'توصيل';

  @override
  String get roleCustomer => 'عميل';

  @override
  String get orderStatus_cooking => 'قيد الطهي';

  @override
  String assignBranchFor(String title) {
    return 'تعيين فرع — $title';
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
  String get roleVerificationFailed => 'فشل التحقق من الدور';

  @override
  String adminRoleLabel(String role) {
    return 'دور الإدارة: $role';
  }

  @override
  String get gatewayAuthError => 'خطأ في المصادقة. يرجى المحاولة مرة أخرى.';

  @override
  String get gatewayRoleVerificationFailed =>
      'فشل التحقق من الدور. تواصل مع الدعم.';

  @override
  String get gatewayNoAdminAccess => 'ليست لديك صلاحية إدارة.';

  @override
  String get backToHome => 'العودة إلى الرئيسية';

  @override
  String get adminDashboardTitle => 'لوحة الإدارة';

  @override
  String get lockTtlEnforced => 'تم فرض مدة قفل الحجز';

  @override
  String get enforceLockTtl => 'فرض مدة قفل الحجز';

  @override
  String saveFailedWithError(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get settingsSavedSuccessfully => 'تم حفظ الإعدادات بنجاح';

  @override
  String exportShareSubject(String appName) {
    return 'تصدير بيانات $appName';
  }

  @override
  String exportShareBody(String appName) {
    return 'إليك تصدير بياناتك من $appName.';
  }

  @override
  String get required => 'مطلوب';

  @override
  String get dayMonday => 'الاثنين';

  @override
  String get dayTuesday => 'الثلاثاء';

  @override
  String get dayWednesday => 'الأربعاء';

  @override
  String get dayThursday => 'الخميس';

  @override
  String get dayFriday => 'الجمعة';

  @override
  String get daySaturday => 'السبت';

  @override
  String get daySunday => 'الأحد';

  @override
  String get setupLabelRestaurantName => 'اسم المطعم *';

  @override
  String get setupLabelTagline => 'الشعار النصي';

  @override
  String get setupLabelSupportEmail => 'البريد الإلكتروني للدعم';

  @override
  String get setupLabelContactPhone => 'هاتف التواصل';

  @override
  String get setupLabelAddress => 'العنوان';

  @override
  String get setupLabelCurrency => 'العملة';

  @override
  String get setupLabelDefaultLanguage => 'اللغة الافتراضية';

  @override
  String get setupLabelMinimumOrderCents => 'الحد الأدنى للطلب (بالهللة)';

  @override
  String get setupLabelDeliveryFeeType => 'نوع رسوم التوصيل';

  @override
  String get setupLabelDeliveryFeeCents => 'رسوم التوصيل (بالهللة)';

  @override
  String get setupLabelFreeDeliveryThresholdCents =>
      'حد التوصيل المجاني (بالهللة)';

  @override
  String get setupLabelEstimatedPrepTimeMinutes =>
      'وقت التحضير التقديري (بالدقائق)';

  @override
  String get setupLabelServiceChargePercent => 'رسوم الخدمة (%)';

  @override
  String get setupLabelLoyaltyProgramName => 'اسم برنامج الولاء';

  @override
  String get setupLabelPointsPerDollar => 'النقاط لكل دولار';

  @override
  String get setupLabelRedemptionThresholdPoints => 'حد الاستبدال (بالنقاط)';

  @override
  String get setupLabelRedemptionValueCents => 'قيمة الاستبدال (بالهللة)';

  @override
  String get setupLabelSignupBonusPoints => 'نقاط المكافأة للتسجيل';

  @override
  String get setupLabelNotificationTone => 'نغمة الإشعارات';

  @override
  String get setupLabelNotificationOptIn => 'الاشتراك في الإشعارات';

  @override
  String get setupLabelAppStoreName => 'اسم المتجر';

  @override
  String get setupLabelAppDescription => 'وصف التطبيق';

  @override
  String get setupLabelTermsUrl => 'رابط الشروط';

  @override
  String get setupLabelPrivacyUrl => 'رابط الخصوصية';

  @override
  String get setupLabelInstagramUrl => 'رابط إنستغرام';

  @override
  String get setupLabelTiktokUrl => 'رابط تيك توك';

  @override
  String get setupLabelOpenTimeExample => 'وقت الافتتاح (مثال: 09:00)';

  @override
  String get setupLabelCloseTimeExample => 'وقت الإغلاق (مثال: 22:00)';

  @override
  String get mapPickerTitle => 'تعيين موقع التوصيل';

  @override
  String get mapPickerConfirm => 'تأكيد';

  @override
  String get mapPickerPositioning => 'جارٍ تحديد الموقع...';

  @override
  String get mapPickerMovePin => 'حرّك الدبوس لتحديد موقع التوصيل';

  @override
  String get mapPickerLookingUp => 'جارٍ البحث عن العنوان...';

  @override
  String get mapPickerDeliveringTo => 'التوصيل إلى:';

  @override
  String get loadingUserRole => 'جارٍ تحميل دور المستخدم';

  @override
  String cartItemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'السلة، $count عنصر',
      many: 'السلة، $count عنصرًا',
      few: 'السلة، $count عناصر',
      two: 'السلة، عنصران',
      one: 'السلة، عنصر واحد',
      zero: 'السلة فارغة',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get deleteBranch => 'حذف الفرع';

  @override
  String get editMenuItem => 'تعديل عنصر القائمة';

  @override
  String get deleteMenuItem => 'حذف عنصر القائمة';

  @override
  String get deleteMenuItemConfirm =>
      'حذف هذا العنصر من القائمة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String trackerStepOfTotal(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String onboardingPage(int page, int total) {
    return 'الصفحة $page من $total';
  }

  @override
  String onboardingPageDot(int page) {
    return 'صفحة $page';
  }

  @override
  String trackerCurrentStatus(String status) {
    return 'الحالة الحالية: $status';
  }

  @override
  String get inFlightTitle => 'يرجى الانتظار';

  @override
  String get inFlightBody =>
      'لا يزال هناك إجراء قيد التنفيذ. قد تؤدي المغادرة الآن إلى فقدان نتيجة الدفع — يرجى الانتظار قليلاً.';

  @override
  String get removeCartItemTitle => 'إزالة هذا العنصر من السلة؟';

  @override
  String get setupLabelTax => 'الضريبة';

  @override
  String get setupLabelDefaultTaxRate => 'نسبة الضريبة الافتراضية';

  @override
  String get setupLabelState => 'الولاية';

  @override
  String get setupLabelStateRate => 'نسبة ضريبة الولاية';

  @override
  String get setupAddState => 'إضافة ولاية';

  @override
  String get setupTaxHint =>
      'تُخزَّن النسب المئوية لكل ولاية ويستخدمها الخادم عند الدفع. الولايات غير المعروفة تُرفض — لا تُحتسب ضريبة صفرية أبداً.';

  @override
  String get noLocationsHint =>
      'لا توجد فروع مدرجة حاليًا — يمكنك تصفح القائمة في هذه الأثناء.';

  @override
  String get topDishesToday => 'أفضل الأطباق اليوم';

  @override
  String get abandonedCarts => 'السلات المتروكة';

  @override
  String get openAnalyticsConsole => 'فتح لوحة التحليلات';

  @override
  String get externalDataDailyNote =>
      'يفتح لوحة التحليلات الخارجية. تُحدَّث التقارير مرة واحدة يوميًا — الأرقام صحيحة حتى الأمس.';

  @override
  String get externalLinkUnavailable =>
      'تعذّر فتح الرابط الخارجي. حاول مرة أخرى.';

  @override
  String containsAllergen(String allergen) {
    return 'يحتوي على $allergen';
  }

  @override
  String get allergenNameEggs => 'بيض';

  @override
  String get allergenNameMilk => 'حليب';

  @override
  String get allergenNameMustard => 'خردل';

  @override
  String get allergenNamePeanuts => 'فول سوداني';

  @override
  String get allergenNameCrustaceans => 'قشريات';

  @override
  String get allergenNameMolluscs => 'رخويات';

  @override
  String get allergenNameFish => 'سمك';

  @override
  String get allergenNameSesame => 'سمسم';

  @override
  String get allergenNameSoybeans => 'صويا';

  @override
  String get allergenNameSulphites => 'كبريتيت';

  @override
  String get allergenNameTreeNuts => 'مكسرات';

  @override
  String get allergenNameWheatTriticale => 'قمح/تريتيكال';

  @override
  String get allergenNameGluten => 'جلوتين';

  @override
  String get dietaryVegetarian => 'نباتي';

  @override
  String get dietaryPescatarian => 'نباتي مع الأسماك';

  @override
  String get dietaryGlutenFree => 'خالٍ من الجلوتين';

  @override
  String get dietaryDairyFree => 'خالٍ من الألبان';

  @override
  String get dietaryNutFree => 'خالٍ من المكسرات';

  @override
  String get dietaryLabel => 'النظام الغذائي';

  @override
  String get allergensLabel => 'مسببات الحساسية';

  @override
  String get hideItemsContaining => 'إخفاء العناصر التي تحتوي على';

  @override
  String get clearFilters => 'مسح';

  @override
  String get halalCertified => 'حلال معتمد';

  @override
  String get halalClaimExpired => 'انتهت صلاحية الشهادة';

  @override
  String get dietaryNotesLabel => 'ملاحظات التلوث المتبادل';

  @override
  String get halalCertificationSection => 'شهادة الحلال';

  @override
  String get halalCertBodyLabel => 'جهة الاعتماد';

  @override
  String get halalCertExpiryLabel => 'صالحة حتى';
}
