import 'package:flutter/material.dart';

class TermsAndConditions extends StatelessWidget {
  const TermsAndConditions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionTitle('1. Introduction'),
            SectionText(
              'Welcome to Bayanihan! These Terms and Conditions ("Terms") govern your use of the Bayanihan application and services. By accessing or using Bayanihan, you agree to be bound by these Terms.',
            ),
            SectionTitle('2. User Responsibilities'),
            SectionBullet('You must provide accurate and complete information during registration and keep it updated.'),
            SectionBullet('You are responsible for maintaining the confidentiality of your account password.'),
            SectionBullet('You agree to use Bayanihan only for lawful purposes and in accordance with these Terms.'),

            SectionTitle('3. Data Collection and Privacy'),
            SectionText(
              'By using Bayanihan, you consent to the collection and storage of your data for disaster response and related purposes as outlined in our Privacy Policy. Our Privacy Policy is an integral part of these Terms and Conditions. We commit to protecting your data and using it responsibly.',
            ),

            SectionTitle('4. Prohibited Activities'),
            SectionText('You agree not to engage in any of the following prohibited activities:'),
            SectionBullet('Violating any applicable laws or regulations.'),
            SectionBullet('Transmitting any harmful or malicious code.'),
            SectionBullet('Interfering with the operation of Bayanihan.'),
            SectionBullet('Attempting to gain unauthorized access to our systems.'),

            SectionTitle('5. Intellectual Property'),
            SectionText(
              'All content and intellectual property on Bayanihan, including but not limited to text, graphics, logos, and software, are the property of Bayanihan or its licensors and are protected by intellectual property laws.',
            ),

            SectionTitle('6. Disclaimer of Warranties'),
            SectionText(
              'Bayanihan is provided "as is" and "as available" without any warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted, error-free, or secure.',
            ),

            SectionTitle('7. Limitation of Liability'),
            SectionText(
              'To the fullest extent permitted by applicable law, Bayanihan shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (a) your access to or use of or inability to access or use the service; (b) any conduct or content of any third party on the service; (c) any content obtained from the service; and (d) unauthorized access, use or alteration of your transmissions or content.',
            ),

            SectionTitle('8. Governing Law'),
            SectionText(
              'These Terms shall be governed and construed in accordance with the laws of the Philippines, without regard to its conflict of law provisions.',
            ),

            SectionTitle('9. Changes to Terms'),
            SectionText(
              'We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days\' notice prior to any new terms taking effect. By continuing to access or use our Service after those revisions become effective, you agree to be bound by the revised terms.',
            ),

            SectionTitle('10. Contact Us'),
            SectionText(
              'If you have any questions about these Terms, please contact us at support@bayanihan.com.',
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SectionText extends StatelessWidget {
  final String text;
  const SectionText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
    );
  }
}

class SectionBullet extends StatelessWidget {
  final String text;
  const SectionBullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
