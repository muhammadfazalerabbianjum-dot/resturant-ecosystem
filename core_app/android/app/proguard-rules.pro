# FlutterFire / Stripe / Third-Party SDK ProGuard Rules
# Added to suppress R8 missing class warnings during release build obfuscation 
# for React Native Stripe SDK edge cases included via flutter_stripe.

-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# Broad fallback to protect Stripe functionality from aggressive shrinking
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# FlutterFire / Firebase SDK keep rules (P1-08)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep all model classes used with Firestore serialization
-keep class com.carnama.** { *; }

# Keep Kotlin metadata for serialization
-keep class kotlin.Metadata { *; }
