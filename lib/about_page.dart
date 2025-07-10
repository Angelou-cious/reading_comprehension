import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  final String aboutApp =
      'CISC Mobile Reading Comprehension is a student-centered digital learning platform designed to strengthen reading skills among Grade 5 and Grade 6 learners. '
      'Built upon the Philippine Informal Reading Inventory (Phil-IRI) framework, the app allows teachers to assess students through pretests and posttests activities.\n\n'
      'With intuitive tools to manage passages, assign quizzes, and monitor progress, the app fosters both silent and oral reading development in a structured yet engaging way.';

  // Adviser FIRST, with a warm, flowing, respectful paragraph.
  final String collaborationDetails =
      'This project would not have been possible without the invaluable guidance, dedication, and support of our beloved adviser, Professor Gladys S. Ayunar. Her encouragement, wisdom, and unwavering belief in this initiative inspired us to persevere and continually strive for excellence. Her leadership was truly the heart of this achievement.\n\n'
      'We are also deeply grateful to our esteemed professors—Kent Levi Bonifacio, Nathalie Joy G. Casildo, and Jinky G. Marcelo—for their expert guidance, thoughtful feedback, and continued encouragement throughout this journey.\n\n'
      'Our sincere appreciation goes to Leah Culaste Angana, Ph.D., for her vital expertise in the Philippine Informal Reading Inventory (Phil-IRI), which helped shape the app’s development. We also thank Weenkie Jhon A. Marcelo, Ph.D., School Principal of Musuan Integrated School, for his generous support and encouragement.';

  final String counterparts =
      'The CISC Mobile Reading Comprehension app is part of the CISC KIDS series, which includes these complementary educational apps:\n';

  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF15A323),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(fontFamily: 'LexendDeca', color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoHeader(),
              const SizedBox(height: 20),
              _sectionTitle('About the App'),
              _sectionCard(aboutApp),
              const SizedBox(height: 28),
              _sectionTitle('Acknowledgments & Collaboration'),
              _sectionCard(collaborationDetails),
              const SizedBox(height: 28),
              _sectionTitle('Developers'),
              _developerSection(),
              const SizedBox(height: 28),
              _sectionTitle('Counterpart Apps in the Series'),
              _sectionCard(counterparts),
              _counterpartAppList(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFE9FBEF),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.13),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              'assets/images/logo.png',
              height: 110,
              width: 110,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'CISC Mobile Reading Comprehension',
            style: TextStyle(
              fontFamily: 'LexendDeca',
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15A323),
              height: 1.8,
              shadows: [
                Shadow(blurRadius: 2, color: Colors.black12, offset: Offset(0, 2)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'LexendDeca',
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: Color(0xFF15A323),
      ),
    );
  }

  Widget _sectionCard(String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF15A323).withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        content,
        style: const TextStyle(
          fontFamily: 'LexendDeca',
          fontSize: 16,
          color: Colors.black87,
          height: 1.6,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _developerSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _developerCard(
          imagePath: 'assets/images/developer1.png',
          name: 'Dan Ephraim R. Macabenlar',
          role: 'Developer',
        ),
        const SizedBox(width: 10),
        _developerCard(
          imagePath: 'assets/images/developer2.png',
          name: 'Angelou C. Lapad',
          role: 'Developer',
        ),
      ],
    );
  }

  Widget _developerCard({required String imagePath, required String name, required String role}) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.11)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(imagePath, height: 60, width: 60, fit: BoxFit.cover),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'LexendDeca',
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            role,
            style: const TextStyle(
              fontFamily: 'LexendDeca',
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }


  Widget _counterpartAppList()  {
    final apps = [
      {
        'img': 'assets/images/applogo1.2.png',
        'desc': '1. CISC KIDS: Beginning Reading English Fuller – integrates phonics, vocabulary building, and alphabet mastery.',
      },
      {
        'img': 'assets/images/applogo1.2.png',
        'desc': '2. CISC KIDS: Marungko Approach Simula sa Pagbasa – emphasizes sound recognition through the Marungko method.',
      },
    ];

    return Column(
      children: apps.map((app) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(app['img']!, height: 55, width: 55),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  app['desc']!,
                  style: const TextStyle(
                    fontFamily: 'LexendDeca',
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
