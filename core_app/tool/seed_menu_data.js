const admin = require('firebase-admin');

// Using the same credentials from before
const serviceAccount = require('<repo>/resturants-8547d-firebase-adminsdk-fbsvc-ce60b264b3.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'resturants-8547d',
  });
}

const db = admin.firestore();

const sampleItems = [
  {
    id: 'burger_1',
    name: 'Double Smashburger',
    description: 'Two 100% Angus beef patties, american cheese, house sauce on a toasted brioche bun.',
    category: 'Burgers',
    priceCents: 1499,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800&auto=format&fit=crop',
    tags: ['Best Seller', 'Beef'],
  },
  {
    id: 'pizza_1',
    name: 'Margherita Pizza',
    description: 'San Marzano tomato sauce, fresh mozzarella, and basil baked in a wood-fired oven.',
    category: 'Pizza',
    priceCents: 1850,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?q=80&w=800&auto=format&fit=crop',
    tags: ['Vegetarian', 'Classic'],
  },
  {
    id: 'drink_1',
    name: 'Iced Matcha Latte',
    description: 'Premium ceremonial grade matcha poured over oat milk and ice.',
    category: 'Drinks',
    priceCents: 550,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?q=80&w=800&auto=format&fit=crop',
    tags: ['Cold', 'Vegan'],
  },
  {
    id: 'dessert_1',
    name: 'Molten Lava Cake',
    description: 'Warm chocolate cake with a gooey center, served with vanilla bean ice cream.',
    category: 'Desserts',
    priceCents: 899,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?q=80&w=800&auto=format&fit=crop',
    tags: ['Sweet', 'Contains Dairy'],
  },
  {
    id: 'burger_2',
    name: 'Spicy Chicken Sandwich',
    description: 'Crispy southern fried chicken breast, spicy mayo, pickles, toasted bun.',
    category: 'Burgers',
    priceCents: 1299,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?q=80&w=800&auto=format&fit=crop',
    tags: ['Spicy', 'Poultry'],
  },
  {
    id: 'side_1',
    name: 'Truffle Parmesan Fries',
    description: 'Crispy shoestring fries tossed in white truffle oil, parsley, and fresh parmesan.',
    category: 'Sides',
    priceCents: 750,
    branchId: 'branch_main',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?q=80&w=800&auto=format&fit=crop',
    tags: ['Premium'],
  }
];

async function seedMenus() {
  console.log('🍔 Injecting Premium Menu Demo Data...');
  const batch = db.batch();
  
  for (const item of sampleItems) {
    const ref = db.collection('menus').doc(item.id);
    batch.set(ref, item);
  }

  await batch.commit();
  console.log('✅ Successfully seeded 6 stunning menu items into live Firestore!');
  process.exit(0);
}

seedMenus().catch(console.error);
