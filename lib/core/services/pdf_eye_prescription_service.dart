import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/prescription_model/prescription_model.dart';
import '../../models/mr_model/mr_patient_model.dart';
import '../../models/eye_model/fundus_examination_model.dart';

class PDFEyePrescriptionService {
  static Future<void> sharePrescription(PrescriptionModel rx, PatientModel patient, {List<FundusRecord>? recentFundusRecords}) async {
    final pdf = await _generateDocument(rx, patient, recentFundusRecords: recentFundusRecords);

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'EyePrescription_${rx.mrNumber}.pdf',
    );
  }

  static Future<pw.Document> _generateDocument(PrescriptionModel rx, PatientModel patient, {List<FundusRecord>? recentFundusRecords}) async {
    // ignore: avoid_print
    print('📄 [PDFEyePrescriptionService] Generating document. Medicines count: ${rx.medicines.length}');
    
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();


    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => _buildFooter(context, font),
        build: (pw.Context context) => [
          _buildHeader(rx, patient, font, fontBold),
          pw.SizedBox(height: 10),
          _buildPatientStrip(patient, font, fontBold),
          pw.SizedBox(height: 10),
          if (rx.vitals.isNotEmpty) ...[
            _buildVitalsStrip(rx, font, fontBold),
            pw.SizedBox(height: 10),
          ],
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (rx.historyExamination?.isNotEmpty == true || rx.treatment?.isNotEmpty == true || rx.consultantNotes?.isNotEmpty == true || rx.remarks?.isNotEmpty == true) ...[
                      _buildNotes(rx, font, fontBold),
                      pw.SizedBox(height: 10),
                    ],
                    pw.Text('Rx', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
                    pw.SizedBox(height: 10),
                    if (rx.medicines.isNotEmpty)
                      _buildMedicines(rx, font, fontBold)
                    else
                      pw.Text('No medicines prescribed', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 15),
                    if (rx.instructions.isNotEmpty)
                      _buildInstructions(rx, font, fontBold),
                  ],
                ),
              ),
              pw.SizedBox(width: 15),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (rx.referTo?.isNotEmpty == true) ...[
                      _sectionTitle('Follow-ups', fontBold),
                      pw.Text('• ${rx.referTo}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.SizedBox(height: 10),
                    ],
                    if (rx.investigations.isNotEmpty) _buildInvestigations(rx, font, fontBold),
                    if (rx.eyeDetails != null) _buildEyeDetails(rx.eyeDetails!, font, fontBold),
                    if (recentFundusRecords != null && recentFundusRecords.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      _buildRecentFundus(recentFundusRecords, font, fontBold),
                    ],
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
    return pdf;
  }

  static Future<void> printPrescription(PrescriptionModel rx, PatientModel patient, {List<FundusRecord>? recentFundusRecords}) async {
    try {
      final pdf = await _generateDocument(rx, patient, recentFundusRecords: recentFundusRecords);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'EyePrescription_${rx.mrNumber}.pdf',
      );
    } catch (e) {
      rethrow;
    }
  }

  static pw.Widget _buildHeader(PrescriptionModel rx, PatientModel patient, pw.Font font, pw.Font fontBold) {
    final dateStr = DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue900))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Dr. ${rx.doctorName}', style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900)),
              pw.Text('Consultant Ophthalmologist', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('HEALTH CARE HOSPITAL', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900)),
              pw.Text('EYE OPD PRESCRIPTION', style: pw.TextStyle(font: font, fontSize: 10, letterSpacing: 2, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'MR No: ', style: pw.TextStyle(font: font, fontSize: 10)),
                pw.TextSpan(text: rx.mrNumber, style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ])),
              pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 9)),
              if (rx.receiptId != null) pw.Text('Receipt: ${rx.receiptId}', style: pw.TextStyle(font: font, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientStrip(PatientModel patient, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(left: pw.BorderSide(width: 4, color: PdfColors.blue700)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _patientField('Patient', patient.firstName.isNotEmpty ? patient.firstName : '—', font, fontBold),
          _patientField('Age', patient.age != null ? '${patient.age} yrs' : '—', font, fontBold),
          _patientField('Gender', patient.gender.isNotEmpty ? patient.gender : '—', font, fontBold),
          _patientField('Phone', patient.phoneNumber.isNotEmpty ? patient.phoneNumber : '—', font, fontBold),
          _patientField('Father/Husband', patient.guardianName.isNotEmpty ? patient.guardianName : '—', font, fontBold),
        ],
      ),
    );
  }

  static pw.Widget _patientField(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildVitalsStrip(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final vitalsList = rx.vitals.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key.toUpperCase()}: ${e.value}')
        .join('  |  ');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(
        children: [
          pw.Text('VITALS: ', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue700)),
          pw.SizedBox(width: 5),
          pw.Text(vitalsList, style: pw.TextStyle(font: font, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicines(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rx.medicines.asMap().entries.map((e) {
        final med = e.value;
        final index = e.key + 1;
        
        final timing = [
          if (med.morning > 0) 'Morning: ${med.morning}',
          if (med.afternoon > 0) 'Afternoon: ${med.afternoon}',
          if (med.evening > 0) 'Evening: ${med.evening}',
          if (med.night > 0) 'Night: ${med.night}',
        ].join(' | ');

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, style: pw.BorderStyle.dashed))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('$index. ', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
                  pw.Expanded(
                    child: pw.Text(med.medicineName, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
                  ),
                  if (med.forDays.isNotEmpty) pw.Text('${med.forDays} days', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              if (timing.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 15, top: 2),
                  child: pw.Text(timing, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildInstructions(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Instructions', fontBold),
        ...rx.instructions.map((i) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('• $i', style: pw.TextStyle(font: font, fontSize: 10)),
        )),
      ],
    );
  }

  static pw.Widget _buildNotes(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    final notes = [
      if (rx.historyExamination?.isNotEmpty == true) {'label': 'History / Examination', 'val': rx.historyExamination!},
      if (rx.treatment?.isNotEmpty == true) {'label': 'Treatment', 'val': rx.treatment!},
      if (rx.consultantNotes?.isNotEmpty == true) {'label': 'Consultant Notes', 'val': rx.consultantNotes!},
      if (rx.remarks?.isNotEmpty == true) {'label': 'Remarks', 'val': rx.remarks!},
    ];

    if (notes.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Notes', fontBold),
        ...notes.map((n) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800),
              children: [
                pw.TextSpan(text: '${n['label']}: ', style: pw.TextStyle(font: fontBold, color: PdfColors.blue900)),
                pw.TextSpan(text: n['val']!),
              ],
            ),
          ),
        )),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildDiagnosis(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Questionnaire', fontBold),
        ...rx.diagnosis.map((d) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(d.questionText, style: pw.TextStyle(font: fontBold, fontSize: 9)),
              pw.Text('• ${d.answerText ?? ''}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
            ],
          ),
        )),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildInvestigations(PrescriptionModel rx, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Investigations', fontBold),
        pw.Wrap(
          spacing: 4,
          runSpacing: 4,
          children: rx.investigations.map((i) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Text(i.testName, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.blue900)),
          )).toList(),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildEyeDetails(EyePrescriptionDetails eye, pw.Font font, pw.Font fontBold) {
    final hasRefraction = _hasRefractionData(eye.rightRefraction) || 
                          _hasRefractionData(eye.leftRefraction) || 
                          _hasRefractionData(eye.add01Refraction) || 
                          _hasRefractionData(eye.add02Refraction);
    final hasVision = _hasVisionData(eye.rightVision) || _hasVisionData(eye.leftVision);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('EYE DETAILS', style: pw.TextStyle(font: fontBold, fontSize: 10, letterSpacing: 1)),
          pw.SizedBox(height: 8),

          if (hasRefraction) ...[
            pw.Text('REFRACTION', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Eye', 'Sph', 'Cyl', 'Axis', 'VA', 'Add'].map((h) => 
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 8)))
                  ).toList(),
                ),
                if (_hasRefractionData(eye.rightRefraction)) _refractionRow('Right', eye.rightRefraction, font, fontBold),
                if (_hasRefractionData(eye.leftRefraction)) _refractionRow('Left', eye.leftRefraction, font, fontBold),
                if (_hasRefractionData(eye.add01Refraction)) _refractionRow('A D D', eye.add01Refraction, font, fontBold),
                if (_hasRefractionData(eye.add02Refraction)) _refractionRow('A D D', eye.add02Refraction, font, fontBold),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          if (hasVision) ...[
            pw.Text('VISION', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            if (_hasVisionData(eye.rightVision)) _visionRow('Right', eye.rightVision, font, fontBold),
            if (_hasVisionData(eye.leftVision)) _visionRow('Left', eye.leftVision, font, fontBold),
            pw.SizedBox(height: 8),
          ],

          if (eye.presentingComplaints.isNotEmpty) _eyeMetaRow('Presenting Complaints', eye.presentingComplaints, font, fontBold),
          if (eye.complaints.isNotEmpty) _eyeMetaRow('Complaints', eye.complaints.map((c) => c.name).join(', '), font, fontBold),
          if (eye.examinations.isNotEmpty) _eyeMetaRow('Examinations', eye.examinations.map((c) => c.name).join(', '), font, fontBold),
          if (eye.diagnosis.isNotEmpty) _eyeMetaRow('Diagnosis', eye.diagnosis.map((c) => c.name).join(', '), font, fontBold),
          if (eye.advised.isNotEmpty) _eyeMetaRow('Advised', eye.advised.map((c) => c.name).join(', '), font, fontBold),
          if (eye.treatmentType.isNotEmpty) _eyeMetaRow('Treatment', eye.treatmentType, font, fontBold),
          if (eye.remarks.isNotEmpty) _eyeMetaRow('Remarks', eye.remarks, font, fontBold),
        ],
      ),
    );
  }

  static pw.Widget _buildRecentFundus(List<FundusRecord> records, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RECENT FUNDUS EXAMINATIONS', style: pw.TextStyle(font: fontBold, fontSize: 10, letterSpacing: 1)),
          pw.SizedBox(height: 8),
          ...records.map((record) {
            final dateStr = record.examinationDate;
            final findings = record.findings;
            final other = record.otherFindings;

            final findingsStr = findings.entries
                .where((e) => e.value.right == true || e.value.left == true)
                .map((e) {
                  final side = (e.value.right == true && e.value.left == true)
                      ? 'Both'
                      : (e.value.right == true ? 'Right' : 'Left');
                  return '${e.key} ($side)';
                })
                .join(', ');

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Date: $dateStr', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey700)),
                  if (findingsStr.isNotEmpty)
                    pw.Text('Findings: $findingsStr', style: pw.TextStyle(font: font, fontSize: 8)),
                  if (other.isNotEmpty)
                    pw.Text('Other: $other', style: pw.TextStyle(font: font, fontSize: 8, fontStyle: pw.FontStyle.italic)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }


  static bool _hasRefractionData(RefractionMatrix r) {
    return r.sph.isNotEmpty || r.cyl.isNotEmpty || r.axis.isNotEmpty || r.va.isNotEmpty || r.addition.isNotEmpty;
  }

  static pw.TableRow _refractionRow(String label, RefractionMatrix r, pw.Font font, pw.Font fontBold) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.sph.isEmpty ? '-' : r.sph, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.cyl.isEmpty ? '-' : r.cyl, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.axis.isEmpty ? '-' : r.axis, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.va.isEmpty ? '-' : r.va, style: pw.TextStyle(font: font, fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r.addition.isEmpty ? '-' : r.addition, style: pw.TextStyle(font: font, fontSize: 8))),
      ],
    );
  }

  static bool _hasVisionData(VisionStats v) {
    return v.varValue.isNotEmpty || v.ph.isNotEmpty || v.ref.isNotEmpty;
  }

  static pw.Widget _visionRow(String label, VisionStats v, pw.Font font, pw.Font fontBold) {
    final parts = [
      if (v.varValue.isNotEmpty) 'VAR ${v.varValue}',
      if (v.ph.isNotEmpty) 'PH ${v.ph}',
      if (v.ref.isNotEmpty) 'REF ${v.ref}',
    ].join(' | ');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text('$label: $parts', style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  static pw.Widget _eyeMetaRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(font: fontBold, fontSize: 9)),
          pw.TextSpan(text: value, style: pw.TextStyle(font: font, fontSize: 9)),
        ])
      )
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue100, width: 2)),
      ),
      child: pw.Text(title.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue900, letterSpacing: 1)),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Text(
        'This report is generated electronically and does not require a physical signature. Health Care Hospital.',
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }
}
