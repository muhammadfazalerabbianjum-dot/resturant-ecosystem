const admin = require('firebase-admin');

const serviceAccount = require('<repo>/resturants-8547d-firebase-adminsdk-fbsvc-ce60b264b3.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'resturants-8547d',
  });
}
const db = admin.firestore();

async function seedPromotions() {
    console.log("Seeding Hero Promotions into live Firestore...");
    const batch = db.batch();
    
    // High Priority Banner
    const p1 = db.collection('promotions').doc('hero_promo_1');
    batch.set(p1, {
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947', // Free-license placeholder steak
        actionUrl: '/menu',
        isActive: true,
        priority: 1,
        createdAt: new Date().toISOString()
    });

    // Secondary Banner
    const p2 = db.collection('promotions').doc('hero_promo_2');
    batch.set(p2, {
        imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38', // Free-license pizza
        actionUrl: null, // No redirect
        isActive: true,
        priority: 2,
        createdAt: new Date().toISOString()
    });

    await batch.commit();
    console.log("Successfully seeded 2 active hero banners.");
}

seedPromotions().catch(console.error);
