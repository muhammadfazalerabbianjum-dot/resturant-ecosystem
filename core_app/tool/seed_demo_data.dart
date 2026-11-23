// ignore_for_file: avoid_print, unused_local_variable, unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Run this script natively or wire it to a hidden button in the app
/// to instantly flood the database with beautiful demo content.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // If using emulator:
  // FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

  await seedDemoData();
}

Future<void> seedDemoData() async {
  final firestore = FirebaseFirestore.instance;
  print('Seeding demo data into Firestore...');

  final sampleItems = [
    {
      'id': 'burger_1',
      'name': 'Double Smashburger',
      'description':
          'Two 100% Angus beef patties, american cheese, house sauce on a toasted brioche bun.',
      'category': 'Burgers',
      'priceCents': 1499,
      'isAvailable': true,
      'imageUrl':
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800&auto=format&fit=crop',
      'tags': ['Best Seller', 'Beef'],
    },
    {
      'id': 'pizza_1',
      'name': 'Margherita Pizza',
      'description':
          'San Marzano tomato sauce, fresh mozzarella, and basil baked in a wood-fired oven.',
      'category': 'Pizza',
      'priceCents': 1850,
      'isAvailable': true,
      'imageUrl':
          'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?q=80&w=800&auto=format&fit=crop',
      'tags': ['Vegetarian', 'Classic'],
    },
    {
      'id': 'drink_1',
      'name': 'Iced Matcha Latte',
      'description':
          'Premium ceremonial grade matcha poured over oat milk and ice.',
      'category': 'Drinks',
      'priceCents': 550,
      'isAvailable': true,
      'imageUrl':
          'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?q=80&w=800&auto=format&fit=crop',
      'tags': ['Cold', 'Vegan'],
    },
    {
      'id': 'dessert_1',
      'name': 'Molten Lava Cake',
      'description':
          'Warm chocolate cake with a gooey center, served with vanilla bean ice cream.',
      'category': 'Desserts',
      'priceCents': 899,
      'isAvailable': true,
      'imageUrl':
          'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?q=80&w=800&auto=format&fit=crop',
      'tags': ['Sweet', 'Contains Dairy'],
    },
  ];

  final batch = firestore.batch();
  for (var item in sampleItems) {
    // Generate a new Doc ID manually or let Firebase do it. Here we use preset.
    final ref = firestore.collection('menuItems').doc(item['id'] as String);
    batch.set(ref, item);
  }

  await batch.commit();
  print('✅ Successfully seeded 4 premium demo items!');
}
