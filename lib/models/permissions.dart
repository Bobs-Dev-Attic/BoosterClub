/// Granular permissions, each mapping to a manageable part of the site. A
/// user's effective permissions come from their base role plus any delegated
/// grants (which may have an expiry).
const List<String> kPermissions = [
  'manage_events',
  'manage_volunteering',
  'manage_sponsorships',
  'manage_fundraisers',
  'manage_meetings',
  'manage_faqs',
  'manage_funding',
  'manage_history',
  'manage_donations',
  'seed_content',
  'manage_users',
];

const Map<String, String> kPermissionLabels = {
  'manage_events': 'Events',
  'manage_volunteering': 'Volunteering',
  'manage_sponsorships': 'Sponsorships',
  'manage_fundraisers': 'Fundraisers',
  'manage_meetings': 'Meetings & Minutes',
  'manage_faqs': 'FAQ',
  'manage_funding': 'Funding Requests',
  'manage_history': 'History Facts',
  'manage_donations': 'Donations',
  'seed_content': 'Load sample content',
  'manage_users': 'Users & Roles',
};

/// Collections/areas that map 1:1 to a manage permission (used by the admin UI).
const Map<String, String> kPermissionForCollection = {
  'events': 'manage_events',
  'volunteering': 'manage_volunteering',
  'sponsorships': 'manage_sponsorships',
  'fundraisers': 'manage_fundraisers',
  'meetings': 'manage_meetings',
  'faqs': 'manage_faqs',
  'funding_requests': 'manage_funding',
  'history_facts': 'manage_history',
};
