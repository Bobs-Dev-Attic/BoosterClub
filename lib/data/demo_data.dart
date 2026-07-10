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
          latitude: 39.0349,
          longitude: -77.1136,
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
          allDay: true,
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

  static List<GalleryImage> gallery() => [
        GalleryImage(
          id: 'g1',
          title: 'Walter Johnson High School',
          imageUrl: 'assets/images/wj-frontb.jpg',
          caption: 'The front of the WJ building on a fall afternoon.',
          tags: const ['campus', 'school'],
          uploadedAt: _future(-2),
          fileName: 'wj-frontb.jpg',
          width: 1600,
          height: 1067,
          sizeBytes: 412000,
        ),
        GalleryImage(
          id: 'g2',
          title: 'Wildcats Crest',
          imageUrl: 'assets/images/wj_logo.png',
          caption: 'Official Walter Johnson Wildcats logo.',
          tags: const ['logo', 'branding'],
          uploadedAt: _future(-5),
          fileName: 'wj_logo.png',
          width: 512,
          height: 512,
          sizeBytes: 48000,
          public: false,
        ),
      ];

  static List<LegalDocument> legalDocuments() => const [
        LegalDocument(id: 'terms', title: 'Terms of Use', body: _termsBody),
        LegalDocument(
            id: 'privacy', title: 'Privacy Policy', body: _privacyBody),
      ];

  static List<FundraisingCampaign> fundraisingCampaigns() => [
        FundraisingCampaign(
          id: 'camp_mulch',
          title: 'Spring Mulch Sale',
          description:
              'Annual hardwood mulch sale — pickup or driveway delivery '
              'the first weekend of April.',
          type: CampaignType.product,
          stage: CampaignStage.selling,
          goalAmount: 6000,
          startsAt: _future(-14),
          endsAt: _future(21),
          vendorName: 'Bethesda Landscape Supply',
          vendorContact: 'orders@bethesdalandscape.example · (301) 555-0142',
          notes: 'Delivery teams meet at the WJ back lot at 7:30am.',
          createdAt: _future(-15),
          products: const [
            CampaignProduct(
                id: 'p_hw',
                name: '3 cu ft Hardwood Mulch',
                price: 6,
                goalQty: 800,
                vendorIds: ['v_mulch']),
            CampaignProduct(
                id: 'p_bk',
                name: '3 cu ft Black Dyed Mulch',
                price: 7,
                goalQty: 300,
                vendorIds: ['v_mulch']),
          ],
        ),
        FundraisingCampaign(
          id: 'camp_shirt',
          title: 'Wildcat Spirit T-Shirts',
          description: 'Screen-printed spirit tees in green and white.',
          type: CampaignType.product,
          stage: CampaignStage.ordering,
          goalAmount: 2500,
          startsAt: _future(-30),
          endsAt: _future(-2),
          vendorName: 'Rockville Screen Printing',
          vendorContact: '(301) 555-0199',
          createdAt: _future(-31),
          products: const [
            CampaignProduct(
                id: 'p_tee',
                name: 'Spirit Tee',
                price: 18,
                options: ['YS', 'YM', 'YL', 'S', 'M', 'L', 'XL', 'XXL'],
                goalQty: 150,
                vendorIds: ['v_print']),
          ],
        ),
        FundraisingCampaign(
          id: 'camp_raffle',
          title: 'Grand Prize Raffle',
          description: '50/50 raffle drawn at the spring concert.',
          type: CampaignType.raffle,
          stage: CampaignStage.planning,
          goalAmount: 3000,
          startsAt: _future(10),
          endsAt: _future(45),
          createdAt: _future(-3),
          products: const [
            CampaignProduct(id: 'p_1', name: 'Single Ticket', price: 5),
            CampaignProduct(id: 'p_6', name: '6-Ticket Book', price: 25),
          ],
        ),
      ];

  static List<FundraisingOrder> fundraisingOrders() => [
        FundraisingOrder(
          id: 'ord_1',
          campaignId: 'camp_mulch',
          customerName: 'The Nguyen Family',
          customerContact: '(240) 555-0111',
          deliveryAddress: '9312 Cedar Lane, Bethesda, MD 20814',
          paymentStatus: PaymentStatus.paid,
          paymentMethod: 'Check #1042',
          fulfillmentStatus: FulfillmentStatus.pending,
          assignedTo: 'Team A',
          createdAt: _future(-6),
          items: const [
            OrderItem(
                productName: '3 cu ft Hardwood Mulch', quantity: 20, unitPrice: 6),
          ],
        ),
        FundraisingOrder(
          id: 'ord_2',
          campaignId: 'camp_mulch',
          customerName: 'Coach Rivera',
          customerContact: 'rivera@example.com',
          deliveryAddress: 'Pickup at school',
          paymentStatus: PaymentStatus.unpaid,
          paymentMethod: 'Cash on pickup',
          fulfillmentStatus: FulfillmentStatus.pending,
          createdAt: _future(-4),
          items: const [
            OrderItem(
                productName: '3 cu ft Black Dyed Mulch', quantity: 10, unitPrice: 7),
            OrderItem(
                productName: '3 cu ft Hardwood Mulch', quantity: 5, unitPrice: 6),
          ],
        ),
        FundraisingOrder(
          id: 'ord_3',
          campaignId: 'camp_shirt',
          customerName: 'Dana Park',
          customerContact: '(301) 555-0173',
          paymentStatus: PaymentStatus.paid,
          paymentMethod: 'Online',
          fulfillmentStatus: FulfillmentStatus.delivered,
          assignedTo: 'Front office',
          createdAt: _future(-10),
          items: const [
            OrderItem(
                productName: 'Spirit Tee', option: 'L', quantity: 2, unitPrice: 18),
            OrderItem(
                productName: 'Spirit Tee', option: 'YM', quantity: 1, unitPrice: 18),
          ],
        ),
      ];

  static List<Vendor> fundraisingVendors() => [
        Vendor(
          id: 'v_mulch',
          title: 'Bethesda Landscape Supply',
          contact: 'orders@bethesdalandscape.example · (301) 555-0142',
          notes: 'Delivers pallets to the school lot; net-15 terms.',
          createdAt: _future(-40),
        ),
        Vendor(
          id: 'v_print',
          title: 'Rockville Screen Printing',
          contact: '(301) 555-0199',
          notes: '10-day turnaround once art is approved.',
          createdAt: _future(-40),
        ),
      ];
}

// ---- Starter legal documents ---------------------------------------------
// DRAFT starter text intended to be reviewed by a licensed attorney before it
// is relied upon. Bracketed [PLACEHOLDERS] must be completed. Editable in-app by
// a Policy Admin (Admin → Legal).

const String _termsBody = '''
# Terms of Use

_Last updated: [EFFECTIVE DATE]_

**DRAFT — This is a starter template, not legal advice. Have a licensed attorney review and adapt it before you rely on it.**

By creating an account or using the WJ Booster Club application and website (the "Service"), operated by [LEGAL ENTITY NAME] ("we", "us", or "our") in support of Walter Johnson High School, you agree to these Terms of Use (the "Terms"). If you do not agree, do not use the Service.

## 1. Who May Use the Service
You must be at least 13 years old to create an account. If you are under 18, you may use the Service only with the involvement and consent of a parent or legal guardian. By using the Service you represent that you meet these requirements and that the information you provide is accurate.

## 2. Accounts and Security
- Sign-in is provided through email sign-in links and third-party sign-in (e.g., Google). You are responsible for maintaining the confidentiality of access to your email and account.
- You are responsible for all activity that occurs under your account. Notify us promptly at [CONTACT EMAIL] of any unauthorized use.
- We may suspend or terminate accounts that violate these Terms.

## 3. Acceptable Use
You agree not to:
- Use the Service for any unlawful purpose or in violation of school policy.
- Upload content that is unlawful, harassing, defamatory, infringing, or that contains another person's private information without permission.
- Attempt to gain unauthorized access to the Service, other accounts, or our systems.
- Interfere with or disrupt the integrity or performance of the Service.

## 4. Content You Submit
- You may submit content such as funding requests, volunteer sign-ups, and images ("Your Content"). You retain ownership of Your Content.
- You grant us a non-exclusive, royalty-free license to host, display, and use Your Content solely to operate and promote the Booster Club and the Service.
- You represent that you have the rights to submit Your Content and that it does not violate the rights of others. Do not upload images of minors without appropriate consent.
- We may remove content that violates these Terms at our discretion.

## 5. Donations and Payments
- Donations are processed by a third-party payment provider (PayPal). We do not store your full payment card details.
- Unless required by law or stated otherwise in writing, **donations are non-refundable**. To ask about a donation, contact [CONTACT EMAIL].
- We do not provide tax or legal advice. Consult your advisor regarding the deductibility of any contribution, including our tax-exempt status under [TAX STATUS / EIN, IF APPLICABLE].

## 6. Intellectual Property
The Service, excluding Your Content, including its design, text, and logos, is owned by us or our licensors and is protected by law. You may not copy or reuse it except as permitted by these Terms or with our written permission.

## 7. Third-Party Services
The Service relies on third parties (for example, Google Firebase for hosting and data storage and PayPal for payments) and may link to third-party sites. We are not responsible for third-party services or content. Your use of them is governed by their terms and policies.

## 8. Disclaimers
The Service is provided "AS IS" and "AS AVAILABLE" without warranties of any kind, whether express or implied, to the fullest extent permitted by law. We do not warrant that the Service will be uninterrupted, secure, or error-free.

## 9. Limitation of Liability
To the fullest extent permitted by law, we and our volunteers and officers will not be liable for any indirect, incidental, special, or consequential damages, or for any loss of data, arising from your use of the Service. Our total liability for any claim will not exceed [AMOUNT, e.g., US \$100].

## 10. Indemnification
You agree to indemnify and hold us harmless from claims arising out of your use of the Service or your violation of these Terms, to the extent permitted by law.

## 11. Termination
We may suspend or end your access to the Service at any time. Sections that by their nature should survive termination (including Sections 4–10) will survive.

## 12. Changes to These Terms
We may update these Terms from time to time. Material changes will be posted here with a new "Last updated" date. Your continued use after changes take effect constitutes acceptance.

## 13. Governing Law
These Terms are governed by the laws of the State of Maryland, USA, without regard to conflict-of-laws rules. Disputes will be resolved in the state or federal courts located in [COUNTY], Maryland, unless another process is required by law.

## 14. Contact
Questions about these Terms: [CONTACT EMAIL] · [MAILING ADDRESS].
''';

const String _privacyBody = '''
# Privacy Policy

_Last updated: [EFFECTIVE DATE]_

**DRAFT — This is a starter template, not legal advice. Have a licensed attorney review and adapt it before you rely on it.**

This Privacy Policy explains how [LEGAL ENTITY NAME] ("we", "us", or "our"), in support of Walter Johnson High School, collects, uses, and shares information when you use the WJ Booster Club application and website (the "Service").

## 1. Information We Collect
- **Account information** you provide: name, email address, and optionally phone number, mailing address, and organization.
- **Content you submit**: funding requests (which may include coach and parent names and emails and participant counts), volunteer sign-ups, meeting materials, and images you upload.
- **Donation information**: amount, designation, and a payment confirmation from our payment processor (PayPal). We do **not** collect or store your full payment card number.
- **Interest and preference settings**, such as email opt-in and selected interests.
- **Technical data** collected automatically, such as device/browser type and app usage, and local storage used to keep you signed in and remember preferences.

## 2. How We Use Information
- To operate the Service: create and manage your account, display events and content, and process volunteer sign-ups and funding requests.
- To process and record donations through our payment processor.
- To communicate with you, including updates you have opted in to receive.
- To maintain the security and integrity of the Service and keep an internal audit log of administrative changes.
- To comply with legal obligations.

## 3. How We Share Information
We do **not** sell your personal information. We share it only:
- **With service providers** that operate the Service on our behalf — for example, Google Firebase (hosting, authentication, database, and storage) and PayPal (payment processing) — under their terms and privacy policies.
- **For legal reasons**, if required by law or to protect rights, safety, or the integrity of the Service.
- **With your direction or consent**, for example content you choose to make publicly visible.

## 4. Public Content
Some content is publicly visible by design (for example, events, sponsor listings, gallery images, and the content of published policies). Do not submit information you do not want to be public in those areas.

## 5. Data Retention
We keep personal information for as long as your account is active or as needed to provide the Service, comply with legal obligations, resolve disputes, and enforce agreements. You may request deletion as described below.

## 6. Security
We use reasonable safeguards to protect information, including encryption in transit and at rest provided by our hosting platform, and role-based access controls. No method of transmission or storage is 100% secure, and we cannot guarantee absolute security.

## 7. Your Choices and Rights
- **Access and correction**: You can view and update your profile in the app.
- **Email preferences**: You can opt out of update emails in your profile settings.
- **Deletion**: You may request deletion of your account and associated personal information by contacting [CONTACT EMAIL], subject to records we must retain (for example, donation records).
- Depending on where you live, you may have additional rights (for example, under the California Consumer Privacy Act or other applicable laws). We do not sell personal information.

## 8. Children's Privacy
The Service is intended for parents, guardians, school community members, and students aged 13 and older. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us information, contact [CONTACT EMAIL] and we will delete it. Because the Service supports a school community, please be mindful of information about students that you choose to submit.

## 9. Third-Party Links and Services
The Service may link to or rely on third-party services (such as PayPal and Google). Their handling of your information is governed by their own privacy policies, which we encourage you to review.

## 10. International Users
The Service is operated in the United States. If you access it from outside the United States, you understand your information will be processed in the United States.

## 11. Changes to This Policy
We may update this Policy from time to time. Material changes will be posted here with a new "Last updated" date.

## 12. Contact
Questions or requests regarding your privacy: [CONTACT EMAIL] · [MAILING ADDRESS].
''';
