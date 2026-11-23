const userRequiredFields = ['email', 'role', 'createdAt'];
const orderRequiredFields = [
  'customerId',
  'items',
  'totalCents',
  'status',
  'createdAt',
];
const loyaltyRequiredFields = ['points'];
// WHY: BranchInfo.fromDoc (branch_service.dart) reads `name`/`address` and
// `coordinates` as a GeoPoint. The schema list must match the actual storage
// shape — the storage shape is the source of truth (Law 25).
const branchRequiredFields = ['name', 'address', 'coordinates'];
