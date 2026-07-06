import '../models/content_models.dart';

/// Seed data used when [AppConfig.demoMode] is true so the app is fully
/// browsable without a live Firebase backend.
class DemoData {
  static DateTime _future(int days) =>
      DateTime(2026, 7, 6).add(Duration(days: days));

  static List<SchoolEvent> events() => [
        SchoolEvent(
          id: 'e1',
          title: 'Fall Sports Kickoff Rally',
          description:
              'Join us in the main gym to cheer on all fall sports teams as the new season begins. Free spirit gear for the first 100 students!',
          startsAt: _future(20),
          location: 'Main Gymnasium',
        ),
        SchoolEvent(
          id: 'e2',
          title: 'Homecoming Football Game',
          description:
              'Lincoln Lions take on the crosstown rivals. Tailgate opens at 4pm, kickoff at 7pm. Booster Club concession proceeds fund team travel.',
          startsAt: _future(45),
          location: 'Memorial Stadium',
        ),
        SchoolEvent(
          id: 'e3',
          title: 'Marching Band Showcase',
          description:
              'An evening celebrating our award-winning marching band and color guard ahead of the state competition.',
          startsAt: _future(12),
          location: 'Performing Arts Center',
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
        Sponsorship(
          id: 's1',
          title: 'Platinum Lion Sponsor',
          description:
              'Our top tier partnership for businesses that want maximum visibility across all athletic and arts programs.',
          amount: 5000,
          tier: 'Platinum',
          benefits: [
            'Logo on stadium banner',
            'Full-page program ad',
            'PA announcements at all home games',
            'Website & app featured placement',
          ],
        ),
        Sponsorship(
          id: 's2',
          title: 'Gold Lion Sponsor',
          description:
              'Great exposure for local businesses supporting student athletes and performers.',
          amount: 2500,
          tier: 'Gold',
          benefits: [
            'Logo on team website & app',
            'Half-page program ad',
            'Social media shout-outs',
          ],
        ),
        Sponsorship(
          id: 's3',
          title: 'Silver Lion Sponsor',
          description:
              'An affordable way to show your community pride and support.',
          amount: 1000,
          tier: 'Silver',
          benefits: ['Quarter-page program ad', 'Website listing'],
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
          title: 'Lions 5K Fun Run',
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
              'Buy Lincoln Lions hoodies, tees and hats. Every purchase gives back to the athletic programs.',
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
        FaqItem(
          id: 'q1',
          question: 'What is the Booster Club?',
          answer:
              'We are a parent- and community-run nonprofit that raises funds and volunteers to support all athletic and arts programs at Lincoln High School.',
          order: 1,
        ),
        FaqItem(
          id: 'q2',
          question: 'How do I become a member?',
          answer:
              'Create an account in this app and choose a membership level, or attend any general meeting. Members get voting rights and early event access.',
          order: 2,
        ),
        FaqItem(
          id: 'q3',
          question: 'Where does the money go?',
          answer:
              'Funds are distributed through our grant process to teams and clubs for uniforms, equipment, travel, scholarships and facility improvements.',
          order: 3,
        ),
        FaqItem(
          id: 'q4',
          question: 'How can my business sponsor?',
          answer:
              'Visit the Sponsorships section to view tiers and benefits, then contact us directly or create a sponsor account.',
          order: 4,
        ),
      ];
}
