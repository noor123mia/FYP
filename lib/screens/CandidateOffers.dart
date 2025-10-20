import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OfferLetterScreen(),
    );
  }
}

class OfferLetterScreen extends StatelessWidget {
  // Sample data for offer letters
  final List<Map<String, String>> offerLetters = [
    {
      'company': 'Tech Corp',
      'position': 'Software Engineer',
      'salary': '\$80,000/year',
      'startDate': '2025-06-01',
    },
    {
      'company': 'Innovate Solutions',
      'position': 'Product Manager',
      'salary': '\$90,000/year',
      'startDate': '2025-06-15',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offer Letters'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: offerLetters.length,
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.only(bottom: 16.0),
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company: ${offerLetters[index]['company']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Position: ${offerLetters[index]['position']}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Salary: ${offerLetters[index]['salary']}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Start Date: ${offerLetters[index]['startDate']}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Handle accept action
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Offer Accepted!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text('Accept', style: TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Handle reject action
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Offer Rejected!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text('Reject', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
