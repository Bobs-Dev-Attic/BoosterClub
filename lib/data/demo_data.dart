import '../models/content_models.dart';

/// Seed data used when [AppConfig.demoMode] is true so the app is fully
/// browsable without a live Firebase backend.
class DemoData {
  static DateTime _future(int days) =>
      DateTime(2026, 7, 6).add(Duration(days: days));

  static DateTime _at(int days, int hour, int minute) =>
      DateTime(2026, 7, 6, hour, minute).add(Duration(days: days));

  static List<SchoolEvent> events() => [
        SchoolEvent(
          id: 'e1',
          title: 'Fall Sports Kickoff Rally',
          description:
              'Join us in the main gym to cheer on all fall sports teams as the new season begins. Free spirit gear for the first 100 students!',
          startsAt: _at(20, 18, 0),
          endsAt: _at(20, 20, 0),
          location: 'Main Gymnasium',
          category: 'Athletics',
        ),
        SchoolEvent(
          id: 'e2',
          title: 'Homecoming Football Game',
          description:
              'Walter Johnson Wildcats take on the crosstown rivals. Tailgate opens at 4pm, kickoff at 7pm. Booster Club concession proceeds fund team travel.',
          startsAt: _at(45, 16, 0),
          endsAt: _at(45, 22, 0),
          location: 'Memorial Stadium',
          category: 'Athletics',
        ),
        SchoolEvent(
          id: 'e3',
          title: 'Marching Band Showcase',
          description:
              'An evening celebrating our award-winning marching band and color guard ahead of the state competition.',
          startsAt: _at(12, 19, 0),
          endsAt: _at(12, 21, 0),
          location: 'Performing Arts Center',
          category: 'Arts',
        ),
        SchoolEvent(
          id: 'e4',
          title: 'Booster Club Membership Deadline',
          description:
              'Last day to join at the early-bird rate and be listed in the fall program.',
          startsAt: _at(9, 23, 30),
          location: 'Online',
          category: 'Deadline',
        ),
        SchoolEvent(
          id: 'e5',
          title: 'Professional Day — No School',
          description: 'Schools closed for students; staff professional development.',
          startsAt: _at(28, 0, 0),
          location: 'District-wide',
          category: 'School Holiday',
        ),
        SchoolEvent(
          id: 'e6',
          title: 'Early Release — Half Day',
          description: 'Half day for students; dismissal at 12:15 PM.',
          startsAt: _at(33, 8, 0),
          endsAt: _at(33, 12, 15),
          location: 'Walter Johnson HS',
          category: 'Half Day',
        ),
        SchoolEvent(
          id: 'e7',
          title: 'Concession Stand Volunteers Needed',
          description:
              'Sign up to staff the concession stand at Friday night football. Two-hour shifts.',
          startsAt: _at(18, 17, 0),
          endsAt: _at(18, 21, 0),
          location: 'Memorial Stadium',
          category: 'Volunteer',
        ),
      ];

  static List<VolunteerOpportunity> volunteering() => [
        VolunteerOpportunity(
          id: 'v1',
          title: 'Concession Stand — Home Games',
          description:
              'Help serve concessions during home football games. Two-hour shifts, training provided. A great way to support the teams!',
          date: _future(45),
          spotsNeeded: 12,
          spotsFilled: 7,
        ),
        VolunteerOpportunity(
          id: 'v2',
          title: 'Fundraiser Setup Crew',
          description:
              'Set up tables, signage and decorations for the annual gala. Heavy lifting welcome but not required.',
          date: _future(60),
          spotsNeeded: 8,
          spotsFilled: 3,
        ),
        VolunteerOpportunity(
          id: 'v3',
          title: 'Team Photo Day Check-in',
          description:
              'Greet families and manage the check-in line for fall team photos.',
          date: _future(15),
          spotsNeeded: 6,
          spotsFilled: 6,
        ),
      ];

  static List<Sponsorship> sponsorships() => [
        const Sponsorship(
          id: 's1',
          title: 'One-Year Corporate Stadium Banner',
          description:
              'Prominently featured in the WJ stadium for one full year, your '
              'banner is visible to thousands of fans at WJ and community-wide '
              'sporting events.',
          amount: 1000,
          tier: 'Corporate',
          benefits: [
            '3½ × 9 ft weather-resistant banner',
            'Displayed on the stadium fence, easily seen by all fans',
            'Visible for one full year',
            'Reaches thousands at WJ & community sporting events',
          ],
        ),
      ];

  static List<FundingRequest> fundingRequests() => [
        FundingRequest(
          id: 'f1',
          title: 'New Volleyball Uniforms',
          description:
              'The girls varsity volleyball team is requesting funds for 15 new home and away uniform sets.',
          amountRequested: 2200,
          requestedBy: 'Volleyball Booster',
          status: 'approved',
          submittedAt: _future(-10),
        ),
        FundingRequest(
          id: 'f2',
          title: 'Robotics Club Competition Travel',
          description:
              'Support to cover registration and travel for the regional robotics championship.',
          amountRequested: 3500,
          requestedBy: 'Robotics Club',
          status: 'pending',
          submittedAt: _future(-3),
        ),
        FundingRequest(
          id: 'f3',
          title: 'Theater Lighting Upgrade',
          description:
              'Replace aging stage lighting for the spring musical production.',
          amountRequested: 4800,
          requestedBy: 'Drama Department',
          status: 'funded',
          submittedAt: _future(-30),
        ),
      ];

  static List<FundraisingEvent> fundraisers() => [
        FundraisingEvent(
          id: 'fr1',
          title: 'Annual Booster Gala',
          description:
              'Our signature black-tie dinner and silent auction. All proceeds support scholarships and program grants.',
          goalAmount: 25000,
          raisedAmount: 18450,
          endsAt: _future(60),
        ),
        FundraisingEvent(
          id: 'fr2',
          title: 'Wildcat 5K Fun Run',
          description:
              'A family-friendly run/walk around campus. Registration and sponsorships fuel the general fund.',
          goalAmount: 10000,
          raisedAmount: 6200,
          endsAt: _future(35),
        ),
        FundraisingEvent(
          id: 'fr3',
          title: 'Spirit Wear Drive',
          description:
              'Buy Walter Johnson Wildcats hoodies, tees and hats. Every purchase gives back to the athletic programs.',
          goalAmount: 8000,
          raisedAmount: 7550,
          endsAt: _future(20),
        ),
      ];

  static List<Meeting> meetings() => [
        Meeting(
          id: 'm1',
          title: 'General Membership Meeting — July',
          description:
              'Monthly open meeting. Budget review, upcoming events and volunteer coordination.',
          meetingDate: _future(8),
          location: 'Library Media Center',
          minutesUrl: null,
        ),
        Meeting(
          id: 'm2',
          title: 'Board Meeting — June (Minutes)',
          description:
              'Approved the fall fundraising calendar and the volleyball uniform grant. Minutes available.',
          meetingDate: _future(-25),
          location: 'Room 214',
          minutesUrl: 'https://example.com/minutes/june-board.pdf',
        ),
        Meeting(
          id: 'm3',
          title: 'Board Meeting — May (Minutes)',
          description:
              'Elected the incoming officer slate and reviewed year-end financials.',
          meetingDate: _future(-56),
          location: 'Room 214',
          minutesUrl: 'https://example.com/minutes/may-board.pdf',
        ),
      ];

  static List<FaqItem> faqs() => [
        const FaqItem(
          id: 'q1',
          question: 'What is the Booster Club?',
          answer:
              'We are a parent- and community-run nonprofit that raises funds and volunteers to support all athletic and arts programs at Walter Johnson High School.',
          order: 1,
        ),
        const FaqItem(
          id: 'q2',
          question: 'How do I become a member?',
          answer:
              'Create an account in this app and choose a membership level, or attend any general meeting. Members get voting rights and early event access.',
          order: 2,
        ),
        const FaqItem(
          id: 'q3',
          question: 'Where does the money go?',
          answer:
              'Funds are distributed through our grant process to teams and clubs for uniforms, equipment, travel, scholarships and facility improvements.',
          order: 3,
        ),
        const FaqItem(
          id: 'q4',
          question: 'How can my business sponsor?',
          answer:
              'Visit the Sponsorships section to view tiers and benefits, then contact us directly or create a sponsor account.',
          order: 4,
        ),
      ];

  static List<HistoryFact> historyFacts() => [
        const HistoryFact(
          id: 'h1',
          title: 'Walter Johnson opens its doors',
          fact:
              'Walter Johnson High School was established in 1956 in Bethesda, Maryland, and has been home of the Wildcats ever since.',
          month: 9,
          day: 4,
          year: 1956,
        ),
        const HistoryFact(
          id: 'h2',
          title: 'Wildcats spirit',
          fact:
              'The Wildcat mascot — "Celebrating Excellence" — represents Walter Johnson\'s tradition of achievement in academics, athletics and the arts.',
          month: 1,
          day: 1,
        ),
        const HistoryFact(
          id: 'h3',
          title: 'Booster Club founded',
          fact:
              'The Booster Club was formed by parents and community members to fund uniforms, equipment, scholarships and program grants for WJ students.',
          month: 7,
          day: 6,
        ),
      ];
}
