/**
 * Localized push-notification copy (B8-1).
 *
 * The Cloud Functions render every FCM push title/body from this single source
 * of truth. Any bare English literal placed at a push site is a defect: the
 * parity test (`test/notification_copy.test.js`) forces every key to exist in
 * every supported locale, so English can never silently ship to an `ar` user.
 *
 * Placeholders are written as `{token}` and substituted per-recipient by
 * `renderNotification`. Missing tokens FAIL CLOSED: the template token is kept
 * literally rather than emitting an empty string, and a missing key/no-locale
 * lookup falls back to `en` (never a partially-translated document).
 */

export type NotificationKey =
  | 'orderPreparing'
  | 'orderReady'
  | 'orderPickedUp'
  | 'orderDelivered'
  | 'cartRecovery'
  | 'ddosAlert'
  | 'newReservation';

export const NOTIFICATION_LOCALES = ['en', 'ar'] as const;
export type NotificationLocale = (typeof NOTIFICATION_LOCALES)[number];

/** A rendered push notification. */
export interface NotificationCopy {
  title: string;
  body: string;
}

/** Placeholder values injected into `{token}` slots at render time. */
export interface NotificationValues {
  customerName?: string;
  partySize?: number | string;
  /** A locale-formatted time string (never a raw Timestamp). */
  time?: string;
  ip?: string;
}

type CopyEntry = NotificationCopy;
type LocaleTable = Record<string, NotificationCopy>;
type CopyTable = Record<NotificationLocale, LocaleTable>;

const NOTIFICATION_COPY: CopyTable = {
  en: {
    orderPreparing: {
      title: 'Order Confirmed!',
      body: 'The kitchen is preparing your order.',
    },
    orderReady: {
      title: 'Order Ready!',
      body: 'Your order is ready for pickup/delivery.',
    },
    orderPickedUp: {
      title: 'On the way!',
      body: 'Your driver has picked up your order.',
    },
    orderDelivered: {
      title: 'Delivered!',
      body: 'Enjoy your meal. Rate your experience!',
    },
    cartRecovery: {
      title: 'Still hungry?',
      body: 'Your cart is waiting for you!',
    },
    ddosAlert: {
      title: 'CRITICAL: DDOS Alert',
      body: 'High volume of Permission Denied reads detected from IP: {ip}',
    },
    newReservation: {
      title: 'New Reservation!',
      body: '{customerName} booked {partySize} guest(s) at {time}.',
    },
  },
  ar: {
    orderPreparing: {
      title: 'تم تأكيد الطلب!',
      body: 'المطبخ يجهّز طلبك.',
    },
    orderReady: {
      title: 'طلبك جاهز!',
      body: 'طلبك جاهز للاستلام أو التوصيل.',
    },
    orderPickedUp: {
      title: 'في الطريق إليك!',
      body: 'استلم سائقنا طلبك وبدأ بالتوصيل.',
    },
    orderDelivered: {
      title: 'تم التوصيل!',
      body: 'استمتع بوجبتك! لا تنسَ تقييم تجربتك.',
    },
    cartRecovery: {
      title: 'هل ما زلت جائعاً؟',
      body: 'سلة مشترياتك في انتظارك!',
    },
    ddosAlert: {
      title: 'تنبيه أمني عاجل',
      body: 'تم رصد عدد كبير من محاولات الوصول المرفوضة من عنوان IP: {ip}',
    },
    newReservation: {
      title: 'حجز جديد!',
      body: '{customerName} حجز {partySize} ضيوفاً في {time}.',
    },
  },
};

/**
 * Map a raw locale value from a user doc to a supported notification locale.
 * Anything that does not unambiguously resolve to Arabic FAILS CLOSED to `en`
 * — the dictionary fallback, never a missing/partial translation.
 */
export function resolveNotificationLocale(raw: unknown): NotificationLocale {
  if (typeof raw === 'string') {
    const code = raw.trim().toLowerCase().replace(/[-_].*$/, '');
    if (code === 'ar') return 'ar';
  }
  return 'en';
}

/**
 * Render the copy for `key` in the recipient's locale, substituting `{token}`
 * placeholders from `values`. Throws if the key is absent from the locale's
 * table: a missing locale must never ship a silent English fallback.
 */
export function renderNotification(
    key: NotificationKey,
    locale: unknown,
    values: NotificationValues = {},
): NotificationCopy {
  const resolved = resolveNotificationLocale(locale);
  const copy = NOTIFICATION_COPY[resolved][key];
  if (!copy) {
    throw new Error(
        `Notification copy missing for key "${key}" in locale "${resolved}"`,
    );
  }
  return {
    title: substitute(copy.title, values),
    body: substitute(copy.body, values),
  };
}

/** Return every copy key (the required-key schema shared by all locales). */
export function notificationCopyKeys(): NotificationKey[] {
  return Object.keys(NOTIFICATION_COPY.en) as NotificationKey[];
}

/**
 * Parity gate (like B6-4): every locale must declare every key with non-empty
 * {title, body}. Returns the list of defects (`<locale>.<key>`) or an empty
 * array when parity holds.
 */
export function verifyNotificationCopyParity(): string[] {
  const keys = notificationCopyKeys();
  const defects: string[] = [];
  for (const locale of NOTIFICATION_LOCALES) {
    const table = NOTIFICATION_COPY[locale];
    for (const key of keys) {
      const entry: CopyEntry | undefined = table[key];
      if (!entry || entry.title.trim().length === 0 || entry.body.trim().length === 0) {
        defects.push(`${locale}.${key}`);
      }
    }
  }
  return defects;
}

function substitute(template: string, values: NotificationValues): string {
  return template.replace(/\{(\w+)\}/g, (_match, token: string) => {
    const value = (values as Record<string, unknown>)[token];
    return value === undefined || value === null ? `{${token}}` : String(value);
  });
}
