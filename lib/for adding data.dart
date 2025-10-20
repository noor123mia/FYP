import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Firestore function ko manually call karna
  // addJobDescription();

  await addSampleCandidatesToFirestore();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Save Job Description")),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              // addJobDescription(); // Button click per function call
            },
            child: Text("Save to Firestore"),
          ),
        ),
      ),
    );
  }
}

Future<void> addJobDescription() async {
  CollectionReference jobs =
      FirebaseFirestore.instance.collection('job_descriptions');

  Map<String, dynamic> jobData = {
    "title": "Product Manager",
    "position_summary":
        "We are looking for a strategic and customer-focused Product Manager to lead the development and execution of our product roadmap. You will work closely with engineering, design, and business teams to deliver high-impact products that solve real user needs...",
    "responsibilities": [
      "Define product vision, strategy, and roadmap based on market research and user feedback",
      "Collaborate with engineering, design, and marketing teams to deliver high-quality products",
      "Prioritize features and backlog items based on business impact and feasibility",
      "Conduct competitive analysis and identify market opportunities",
      "Define and track key product metrics to measure success",
      "Gather and analyze user feedback to drive continuous product improvement"
    ],
    "required_skills": [
      "Bachelor's degree in Business, Computer Science, Engineering, or related field",
      "3+ years of product management experience in a tech-driven environment",
      "Strong analytical skills with experience in data-driven decision-making",
      "Excellent communication and stakeholder management skills",
      "Experience working with Agile/Scrum methodologies",
      "Ability to translate business goals into technical requirements"
    ],
    "preferred_skills": [
      "Experience with product analytics tools (Amplitude, Mixpanel, Google Analytics)",
      "Technical background (familiarity with APIs, databases, or software development)",
      "Experience in SaaS, B2B, or marketplace products",
      "MBA or advanced degree in a related field"
    ],
    "technical_skills": {
      "Product Management Tools": [
        "Jira",
        "Confluence",
        "Aha!",
        "Productboard"
      ],
      "Analytics & Data": ["SQL", "Google Analytics", "Amplitude", "Looker"],
      "Prototyping & Design": ["Figma", "Miro", "Balsamiq"],
      "Methodologies": ["Agile", "Scrum", "Lean Startup", "Design Thinking"]
    },
    "what_we_offer": [
      "Competitive salary and performance bonuses",
      "Flexible work arrangements (remote/hybrid options)",
      "Opportunity to shape the future of our product",
      "Professional development budget for courses and conferences",
      "Collaborative and innovative work environment"
    ]
  };

  try {
    await jobs.add(jobData);
    print("Product Manager job description added successfully!");
  } catch (e) {
    print("Failed to add job description: $e");
  }
}

// Example Candidate Data
List<Map<String, dynamic>> getSampleCandidateData() {
  return [
    // Example Candidate 1: Software Developer
    {
      'basicInfo': {
        'fullName': 'Alex Johnson',
        'email': 'alex.johnson@example.com',
        'phone': '+1 (555) 123-4567',
        'location': 'San Francisco, USA',
        'profilePictureUrl': 'https://randomuser.me/api/portraits/men/43.jpg',
        'linkedinUrl': 'https://linkedin.com/in/alexjohnson',
        'portfolioUrl': 'https://alexjohnson.dev'
      },
      'education': [
        {
          'degree': 'Bachelor of Science in Computer Science',
          'institution': 'University of California, Berkeley',
          'fieldOfStudy': 'Computer Science',
          'startDate': Timestamp.fromDate(DateTime(2015, 9, 1)),
          'endDate': Timestamp.fromDate(DateTime(2019, 6, 30)),
          'gpa': '3.8'
        },
        {
          'degree': 'Nanodegree in Mobile App Development',
          'institution': 'Udacity',
          'fieldOfStudy': 'Mobile Development',
          'startDate': Timestamp.fromDate(DateTime(2020, 1, 15)),
          'endDate': Timestamp.fromDate(DateTime(2020, 7, 30)),
        }
      ],
      'experience': [
        {
          'jobTitle': 'Software Engineer',
          'company': 'TechCorp Inc.',
          'location': 'San Francisco, USA',
          'startDate': Timestamp.fromDate(DateTime(2019, 8, 1)),
          'endDate': null, // Current job
          'description':
              'Developing and maintaining web applications using React and Node.js. Implementing RESTful APIs and database optimizations.',
          'achievements':
              'Improved application performance by 40%. Led the migration from monolithic architecture to microservices.'
        },
        {
          'jobTitle': 'Software Development Intern',
          'company': 'InnoTech Solutions',
          'location': 'Berkeley, USA',
          'startDate': Timestamp.fromDate(DateTime(2018, 6, 1)),
          'endDate': Timestamp.fromDate(DateTime(2018, 9, 30)),
          'description':
              'Assisted in the development of a mobile app using Flutter. Implemented user authentication and database integration features.',
          'achievements':
              'Delivered a fully-functional feature that was included in the production release.'
        }
      ],
      'skills': {
        'technical': [
          'JavaScript',
          'React',
          'Node.js',
          'Flutter',
          'Dart',
          'Python',
          'MongoDB',
          'Firebase',
          'Git',
          'RESTful APIs',
          'GraphQL'
        ],
        'soft': [
          'Problem Solving',
          'Team Collaboration',
          'Communication',
          'Time Management',
          'Adaptability'
        ],
        'languages': [
          {'name': 'English', 'proficiency': 'Native'},
          {'name': 'Spanish', 'proficiency': 'Intermediate'},
          {'name': 'German', 'proficiency': 'Basic'}
        ]
      },
      'projects': [
        {
          'title': 'Smart Home Control App',
          'description':
              'A Flutter mobile application that allows users to control their smart home devices remotely.',
          'technologiesUsed': ['Flutter', 'Dart', 'Firebase', 'IoT Protocols'],
          'url': 'https://github.com/alexj/smart-home-app'
        },
        {
          'title': 'E-commerce Analytics Dashboard',
          'description':
              'A web-based dashboard for e-commerce businesses to analyze sales and customer behavior.',
          'technologiesUsed': [
            'React',
            'Node.js',
            'Express',
            'MongoDB',
            'D3.js'
          ],
          'url': 'https://github.com/alexj/ecommerce-dashboard'
        }
      ],
      'certifications': [
        {
          'name': 'AWS Certified Developer – Associate',
          'issuingOrganization': 'Amazon Web Services',
          'issueDate': Timestamp.fromDate(DateTime(2021, 3, 15)),
          'expiryDate': Timestamp.fromDate(DateTime(2024, 3, 15))
        },
        {
          'name': 'Professional Scrum Master I (PSM I)',
          'issuingOrganization': 'Scrum.org',
          'issueDate': Timestamp.fromDate(DateTime(2020, 11, 10)),
          'expiryDate': null // No expiry
        }
      ],
      'preferences': {
        'jobTypes': ['Full-time', 'Contract'],
        'workModes': ['Remote', 'Hybrid'],
        'expectedSalaryRange': {'min': 90000, 'max': 120000},
        'willingToRelocate': true,
        'preferredIndustries': ['Technology', 'Finance', 'Healthcare'],
        'noticePeriod': '30 days'
      }
    },

    // Example Candidate 2: UX/UI Designer
    {
      'basicInfo': {
        'fullName': 'Sophia Martinez',
        'email': 'sophia.martinez@example.com',
        'phone': '+1 (555) 987-6543',
        'location': 'Austin, USA',
        'profilePictureUrl': 'https://randomuser.me/api/portraits/women/32.jpg',
        'linkedinUrl': 'https://linkedin.com/in/sophiamartinez',
        'portfolioUrl': 'https://sophiadesigns.com'
      },
      'education': [
        {
          'degree': 'Bachelor of Fine Arts in Graphic Design',
          'institution': 'Rhode Island School of Design',
          'fieldOfStudy': 'Graphic Design',
          'startDate': Timestamp.fromDate(DateTime(2016, 8, 15)),
          'endDate': Timestamp.fromDate(DateTime(2020, 5, 20)),
          'gpa': '3.9'
        }
      ],
      'experience': [
        {
          'jobTitle': 'UX/UI Designer',
          'company': 'CreativeEdge Solutions',
          'location': 'Austin, USA',
          'startDate': Timestamp.fromDate(DateTime(2020, 7, 1)),
          'endDate': Timestamp.fromDate(DateTime(2023, 3, 31)),
          'description':
              'Designed user interfaces for web and mobile applications. Conducted user research and testing to improve product usability and user experience.',
          'achievements':
              'Redesigned the company\'s flagship product resulting in a 25% increase in user engagement.'
        },
        {
          'jobTitle': 'Graphic Design Intern',
          'company': 'AdVision Marketing',
          'location': 'Providence, USA',
          'startDate': Timestamp.fromDate(DateTime(2019, 6, 1)),
          'endDate': Timestamp.fromDate(DateTime(2019, 9, 30)),
          'description':
              'Created visual concepts for digital marketing campaigns. Collaborated with the marketing team to develop brand identities.',
          'achievements':
              'Designed a logo that won an industry award for innovative design.'
        }
      ],
      'skills': {
        'technical': [
          'Figma',
          'Adobe XD',
          'Sketch',
          'Adobe Photoshop',
          'Adobe Illustrator',
          'InVision',
          'HTML/CSS',
          'Prototyping',
          'Wireframing',
          'User Research'
        ],
        'soft': [
          'Creativity',
          'Attention to Detail',
          'Visual Communication',
          'Empathy',
          'Collaborative Design',
          'Client Management'
        ],
        'languages': [
          {'name': 'English', 'proficiency': 'Native'},
          {'name': 'Spanish', 'proficiency': 'Fluent'}
        ]
      },
      'projects': [
        {
          'title': 'Health & Wellness App Redesign',
          'description':
              'Complete redesign of a health tracking application with focus on accessibility and user engagement.',
          'technologiesUsed': [
            'Figma',
            'Adobe XD',
            'Prototyping',
            'User Testing'
          ],
          'url': 'https://sophiadesigns.com/projects/health-app'
        },
        {
          'title': 'E-commerce Mobile App',
          'description':
              'Designed a mobile shopping experience for a fashion retailer with emphasis on visual merchandising and seamless checkout.',
          'technologiesUsed': [
            'Sketch',
            'InVision',
            'User Research',
            'Interaction Design'
          ],
          'url': 'https://sophiadesigns.com/projects/fashion-app'
        }
      ],
      'certifications': [
        {
          'name': 'Certified User Experience Professional',
          'issuingOrganization': 'Nielsen Norman Group',
          'issueDate': Timestamp.fromDate(DateTime(2021, 5, 20)),
          'expiryDate': null
        }
      ],
      'preferences': {
        'jobTypes': ['Full-time'],
        'workModes': ['Remote', 'Hybrid', 'On-site'],
        'expectedSalaryRange': {'min': 80000, 'max': 100000},
        'willingToRelocate': false,
        'preferredIndustries': [
          'Technology',
          'Creative Agencies',
          'E-commerce',
          'Healthcare'
        ],
        'noticePeriod': '2 weeks'
      }
    },

    // Example Candidate 3: Data Scientist
    {
      'basicInfo': {
        'fullName': 'Rahul Sharma',
        'email': 'rahul.sharma@example.com',
        'phone': '+91 9876543210',
        'location': 'Bangalore, India',
        'profilePictureUrl': 'https://randomuser.me/api/portraits/men/67.jpg',
        'linkedinUrl': 'https://linkedin.com/in/rahulsharma',
        'portfolioUrl': 'https://rahulsharma.ai'
      },
      'education': [
        {
          'degree': 'Master of Science in Data Science',
          'institution': 'Indian Institute of Science',
          'fieldOfStudy': 'Data Science',
          'startDate': Timestamp.fromDate(DateTime(2018, 8, 1)),
          'endDate': Timestamp.fromDate(DateTime(2020, 7, 31)),
          'gpa': '9.2/10'
        },
        {
          'degree': 'Bachelor of Technology in Computer Science',
          'institution': 'National Institute of Technology, Trichy',
          'fieldOfStudy': 'Computer Science',
          'startDate': Timestamp.fromDate(DateTime(2014, 7, 15)),
          'endDate': Timestamp.fromDate(DateTime(2018, 5, 30)),
          'gpa': '8.7/10'
        }
      ],
      'experience': [
        {
          'jobTitle': 'Senior Data Scientist',
          'company': 'DataTech Analytics',
          'location': 'Bangalore, India',
          'startDate': Timestamp.fromDate(DateTime(2022, 2, 1)),
          'endDate': null, // Current job
          'description':
              'Leading data science initiatives for financial risk modeling and customer analytics. Developing machine learning models for fraud detection and credit scoring.',
          'achievements':
              'Developed a predictive model that reduced fraud incidents by 35%. Published a research paper on novel anomaly detection techniques.'
        },
        {
          'jobTitle': 'Data Scientist',
          'company': 'InnoVision AI',
          'location': 'Hyderabad, India',
          'startDate': Timestamp.fromDate(DateTime(2020, 8, 15)),
          'endDate': Timestamp.fromDate(DateTime(2022, 1, 15)),
          'description':
              'Analyzed large datasets to extract business insights. Implemented machine learning algorithms for customer segmentation and product recommendation.',
          'achievements':
              'Improved recommendation system accuracy by 28%, leading to 15% increase in conversion rates.'
        },
        {
          'jobTitle': 'Data Science Intern',
          'company': 'TechAnalytics',
          'location': 'Bangalore, India',
          'startDate': Timestamp.fromDate(DateTime(2019, 5, 1)),
          'endDate': Timestamp.fromDate(DateTime(2019, 7, 31)),
          'description':
              'Assisted in data preprocessing and exploratory data analysis. Contributed to developing a natural language processing model for sentiment analysis.',
          'achievements':
              'Built a text classification model with 87% accuracy for customer feedback analysis.'
        }
      ],
      'skills': {
        'technical': [
          'Python',
          'R',
          'SQL',
          'TensorFlow',
          'PyTorch',
          'Scikit-learn',
          'Pandas',
          'Spark',
          'Machine Learning',
          'Deep Learning',
          'NLP',
          'Data Visualization',
          'Statistical Analysis',
          'Big Data'
        ],
        'soft': [
          'Critical Thinking',
          'Research',
          'Data Storytelling',
          'Business Acumen',
          'Problem-solving',
          'Team Leadership'
        ],
        'languages': [
          {'name': 'English', 'proficiency': 'Fluent'},
          {'name': 'Hindi', 'proficiency': 'Native'},
          {'name': 'Tamil', 'proficiency': 'Intermediate'}
        ]
      },
      'projects': [
        {
          'title': 'Customer Churn Prediction Model',
          'description':
              'Built a machine learning model to predict customer churn for a telecom company with 91% accuracy.',
          'technologiesUsed': [
            'Python',
            'Scikit-learn',
            'XGBoost',
            'Feature Engineering'
          ],
          'url': 'https://github.com/rahuls/churn-prediction'
        },
        {
          'title': 'Healthcare Image Classification',
          'description':
              'Developed a deep learning model for medical image classification to assist in early disease detection.',
          'technologiesUsed': [
            'Python',
            'TensorFlow',
            'Keras',
            'CNN',
            'Transfer Learning'
          ],
          'url': 'https://github.com/rahuls/medical-image-classifier'
        },
        {
          'title': 'NLP-based Resume Parser',
          'description':
              'Created an AI system that extracts structured information from resumes using natural language processing techniques.',
          'technologiesUsed': [
            'Python',
            'SpaCy',
            'NLTK',
            'Named Entity Recognition'
          ],
          'url': 'https://github.com/rahuls/resume-parser'
        }
      ],
      'certifications': [
        {
          'name': 'TensorFlow Developer Certificate',
          'issuingOrganization': 'Google',
          'issueDate': Timestamp.fromDate(DateTime(2021, 6, 10)),
          'expiryDate': null
        },
        {
          'name': 'Data Science Professional Certificate',
          'issuingOrganization': 'IBM',
          'issueDate': Timestamp.fromDate(DateTime(2020, 12, 5)),
          'expiryDate': null
        }
      ],
      'preferences': {
        'jobTypes': ['Full-time', 'Contract'],
        'workModes': ['Remote', 'Hybrid'],
        'expectedSalaryRange': {'min': 2000000, 'max': 3000000}, // In INR
        'willingToRelocate': true,
        'preferredIndustries': [
          'Technology',
          'Finance',
          'Healthcare',
          'E-commerce'
        ],
        'noticePeriod': '60 days'
      }
    }
  ];
}

// Function to add sample candidates to Firestore
Future<void> addSampleCandidatesToFirestore() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CollectionReference candidatesCollection =
      firestore.collection('Candidates');

  List<Map<String, dynamic>> sampleCandidates = getSampleCandidateData();

  for (var candidateData in sampleCandidates) {
    try {
      // Add candidate to Firestore
      DocumentReference docRef = await candidatesCollection.add(candidateData);
      print(
          'Added candidate: ${candidateData['basicInfo']['fullName']} with ID: ${docRef.id}');
    } catch (e) {
      print(
          'Error adding candidate: ${candidateData['basicInfo']['fullName']}');
      print('Error details: $e');
    }
  }

  print('Finished adding sample candidates to Firestore');
}

// Function to add a single candidate with UI feedback
Future<void> addCandidateToFirestore(
    BuildContext context, Map<String, dynamic> candidateData) async {
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final CollectionReference candidatesCollection =
        firestore.collection('Candidates');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Adding candidate..."),
            ],
          ),
        );
      },
    );

    // Add candidate to Firestore
    DocumentReference docRef = await candidatesCollection.add(candidateData);

    // Close loading dialog
    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Candidate added successfully with ID: ${docRef.id}'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Close loading dialog if open
    Navigator.pop(context);

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error adding candidate: $e'),
        backgroundColor: Colors.red,
      ),
    );
    throw e;
  }
}

// Example usage in a screen
class AddSampleCandidatesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Sample Candidates'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await addSampleCandidatesToFirestore();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sample candidates added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding sample candidates: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Add All Sample Candidates'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> candidates =
                      getSampleCandidateData();
                  if (candidates.isNotEmpty) {
                    await addCandidateToFirestore(context, candidates[0]);
                  }
                } catch (e) {
                  // Error handling is already done in the function
                }
              },
              child: Text('Add Software Developer Sample'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> candidates =
                      getSampleCandidateData();
                  if (candidates.length > 1) {
                    await addCandidateToFirestore(context, candidates[1]);
                  }
                } catch (e) {
                  // Error handling is already done in the function
                }
              },
              child: Text('Add UX/UI Designer Sample'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> candidates =
                      getSampleCandidateData();
                  if (candidates.length > 2) {
                    await addCandidateToFirestore(context, candidates[2]);
                  }
                } catch (e) {
                  // Error handling is already done in the function
                }
              },
              child: Text('Add Data Scientist Sample'),
            ),
          ],
        ),
      ),
    );
  }
}
