import 'package:flutter/material.dart';

class OfferLetterAutomationScreen extends StatefulWidget {
  const OfferLetterAutomationScreen({Key? key}) : super(key: key);

  @override
  State<OfferLetterAutomationScreen> createState() =>
      _OfferLetterAutomationScreenState();
}

class _OfferLetterAutomationScreenState
    extends State<OfferLetterAutomationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _candidateNameController =
      TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();

  // Dropdown values
  String _selectedTemplate = 'Standard Offer';
  final List<String> _templates = [
    'Standard Offer',
    'Executive Offer',
    'Contract Position',
    'Internship'
  ];

  bool _isGenerating = false;
  bool _isPreviewVisible = false;

  @override
  void dispose() {
    _candidateNameController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _salaryController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDateController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _generateOfferLetter() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isGenerating = true;
      });

      // Simulate API delay
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isGenerating = false;
          _isPreviewVisible = true;
        });
      });
    }
  }

  void _sendOfferLetter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Offer letter sent successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Reset form and preview
    setState(() {
      _isPreviewVisible = false;
      _candidateNameController.clear();
      _positionController.clear();
      _departmentController.clear();
      _salaryController.clear();
      _startDateController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Letter Automation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {},
            tooltip: 'View History',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Form
            Expanded(
              flex: 3,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Offer Letter',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // Template selection
                      const Text(
                        'Select Offer Template:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedTemplate,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        items: _templates.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedTemplate = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Candidate information
                      _buildFormField(
                        controller: _candidateNameController,
                        label: 'Candidate Name',
                        hint: 'Enter full name',
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),

                      _buildFormField(
                        controller: _positionController,
                        label: 'Position',
                        hint: 'Enter job title',
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),

                      _buildFormField(
                        controller: _departmentController,
                        label: 'Department',
                        hint: 'Enter department',
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),

                      _buildFormField(
                        controller: _salaryController,
                        label: 'Annual Salary',
                        hint: 'Enter amount',
                        keyboardType: TextInputType.number,
                        prefix: '\$',
                        validator: (value) {
                          if (value!.isEmpty) return 'Required';
                          if (double.tryParse(value) == null)
                            return 'Invalid amount';
                          return null;
                        },
                      ),

                      _buildFormField(
                        controller: _startDateController,
                        label: 'Start Date',
                        hint: 'Select date',
                        readOnly: true,
                        suffix: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _showDatePicker,
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                        onTap: _showDatePicker,
                      ),

                      const SizedBox(height: 16),

                      // Custom terms and conditions
                      const Text(
                        'Additional Terms',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          title: const Text('Probation Period (3 months)'),
                          value: true,
                          onChanged: (bool? value) {},
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          title: const Text('Health Insurance'),
                          value: true,
                          onChanged: (bool? value) {},
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          title: const Text('401(k) Plan'),
                          value: true,
                          onChanged: (bool? value) {},
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          title: const Text('Stock Options'),
                          value: false,
                          onChanged: (bool? value) {},
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isGenerating ? null : _generateOfferLetter,
                              icon: _isGenerating
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.file_present),
                              label: Text(_isGenerating
                                  ? 'Generating...'
                                  : 'Generate Offer Letter'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _formKey.currentState!.reset();
                              setState(() {
                                _isPreviewVisible = false;
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset Form'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Template gallery
                      if (!_isPreviewVisible) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Template Gallery',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildTemplateCard('Standard', Colors.blue),
                              _buildTemplateCard('Executive', Colors.purple),
                              _buildTemplateCard('Contract', Colors.orange),
                              _buildTemplateCard('Internship', Colors.teal),
                              _buildTemplateCard('Custom', Colors.red),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Right side - Preview
            if (_isPreviewVisible) ...[
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Offer Letter Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isPreviewVisible = false;
                                });
                              },
                              tooltip: 'Close Preview',
                            ),
                          ],
                        ),
                      ),

                      // Preview content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Image.network(
                                  'https://via.placeholder.com/200x50?text=Company+Logo',
                                  height: 50,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Dear ${_candidateNameController.text},',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'We are pleased to offer you the position of:',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _positionController.text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Department: ${_departmentController.text}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'This is a full-time position with the following details:',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                  'Start Date:', _startDateController.text),
                              _buildDetailRow('Annual Salary:',
                                  '\$${_salaryController.text}'),
                              _buildDetailRow('Location:', 'Headquarters'),
                              _buildDetailRow(
                                  'Reports to:', 'Department Manager'),
                              const SizedBox(height: 16),
                              const Text(
                                'Benefits include:',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              _buildBulletPoint(
                                  'Health, dental, and vision insurance'),
                              _buildBulletPoint('401(k) retirement plan'),
                              _buildBulletPoint('Paid time off'),
                              _buildBulletPoint(
                                  'Professional development opportunities'),
                              const SizedBox(height: 16),
                              const Text(
                                'This offer is contingent upon successful completion of a background check and providing proof of eligibility to work in the United States.',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'We look forward to your positive response and having you join our team!',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Sincerely,',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'HR Department',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Company Name',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.download),
                                label: const Text('Download PDF'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _sendOfferLetter,
                                icon: const Icon(Icons.send),
                                label: const Text('Send'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
    String? prefix,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefix,
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(String title, Color color) {
    return Card(
      margin: const EdgeInsets.only(right: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTemplate = '$title Offer';
          });
        },
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description,
                size: 36,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Template',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
