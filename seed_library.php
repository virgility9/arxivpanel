<?php
// seed_library.php — posts the 50 title-cover papers to the Arxiv Library.
//
// WHAT IT DOES
//   1. Signs in to Firebase Auth as YOU (email + password typed in this
//      terminal — never stored, never sent anywhere except Google's
//      sign-in endpoint, and never printed).
//   2. Creates one Firestore document per paper in the `papers`
//      collection (status `pending`, exactly like the app's Submit flow),
//      then approves it right away (status `approved`), so it shows in
//      the Library immediately.
//   3. The PDFs and covers are ALREADY uploaded to Cloudinary — their
//      URLs are inside this file. This script only writes Firestore.
//
// HOW TO RUN (on your PC, in the project folder)
//   Copy this file to  C:\Projects\Flutter\arxivpanel\
//   Then run:  C:\xampp\php\php.exe seed_library.php
//   (or just `php seed_library.php` if php is on your PATH)
//   Type your Arxiv email + password when asked, then wait — it posts
//   all 50 and prints progress. Re-running it is safe: papers already
//   posted are recorded in seed_library_done.json and skipped.
//
// OPTIONS
//   --dry-run     Build every request but send nothing. Use it to check
//                 the script works before typing your password.
//   --apikey=KEY  Use this Firebase web apiKey instead of reading it
//                 from lib\firebase\firebase_config.dart.
//   --email=ADDR  Skip the email prompt.
//
// If the sign-in says the API key is not valid, open
// lib\firebase\firebase_config.dart and check `apiKey` matches the real
// key in Firebase console -> Project settings -> Your apps -> Web app.

const PROJECT_ID = 'arxivpanel-e25a8';
const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1/projects/' . PROJECT_ID . '/databases/(default)/documents';
const IDENTITY_BASE = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=';

$dryRun = in_array('--dry-run', $argv ?? []);
$apiKeyArg = null;
$emailArg = null;
foreach ($argv ?? [] as $a) {
    if (str_starts_with($a, '--apikey=')) $apiKeyArg = substr($a, 9);
    if (str_starts_with($a, '--email=')) $emailArg = substr($a, 8);
}

function out($msg) { fwrite(STDOUT, $msg . PHP_EOL); }
function err($msg) { fwrite(STDERR, 'ERROR: ' . $msg . PHP_EOL); }
function fail($msg, $code = 1) { err($msg); exit($code); }

function prompt($label) {
    fwrite(STDOUT, $label);
    $line = fgets(STDIN);
    return $line === false ? '' : trim($line);
}

// --- tiny HTTP helper (cURL) ----------------------------------------------
function httpJson($method, $url, $body, $token = null) {
    $ch = curl_init($url);
    $headers = ['Content-Type: application/json'];
    if ($token !== null) $headers[] = 'Authorization: Bearer ' . $token;
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 30,
    ]);
    if ($body !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    $raw = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr = curl_error($ch);
    curl_close($ch);
    if ($raw === false) return [0, null, 'cURL error: ' . $curlErr];
    $decoded = json_decode($raw, true);
    return [$code, $decoded, $raw];
}

// --- Firestore value encoding ---------------------------------------------
function fsStr($v) { return ['stringValue' => (string) $v]; }
function fsInt($v) { return ['integerValue' => (string) (int) $v]; }
function fsTs($v) { return ['timestampValue' => $v]; }
function fsArr($items) {
    $values = [];
    foreach ($items as $it) $values[] = fsStr($it);
    return ['arrayValue' => empty($values) ? new stdClass() : ['values' => $values]];
}

// --- checks -----------------------------------------------------------------
if (!function_exists('curl_init')) {
    fail("PHP cURL extension is missing. With XAMPP it is on by default — make sure you run the XAMPP php.exe: C:\\xampp\\php\\php.exe seed_library.php");
}

$papersJson = <<<'PAPERS_JSON'
[
 {
  "file": "01_Machine_Learning_Paper_1.pdf",
  "field": "Machine Learning",
  "title": "Predictive Maintenance Through Machine Learning",
  "abstract": "This paper examines industrial equipment failure prediction within the broader field of machine learning. The discussion centers on sensor readings such as vibration, temperature, pressure, and operating hours. The issue matters to maintenance teams because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between industrial equipment failure prediction and practical outcomes. The paper uses a supervised classification and regression workflow as its principal analytical approach. It considers failure risk and remaining useful life as the main dimensions for evaluating the subject. The analysis places particular emphasis on model training, validation data, feature engineering, and deployment monitoring. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how industrial equipment failure prediction can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with industrial equipment failure prediction. It explains why sensor readings such as vibration, temperature, pressure, and operating hours are relevant to the research problem. Attention is given to the needs of maintenance teams. The selected approach, a supervised classification and regression workflow, provides a consistent structure for examining the available concepts. Evaluation is framed through failure risk and remaining useful life. The paper considers potential benefits such as maintenance scheduling and equipment downtime. At the same time, it recognizes limitations involving sensor drift, rare failures, and changing operating conditions. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding industrial equipment failure prediction.",
  "tags": [
   "predictive",
   "maintenance",
   "machine",
   "learning"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/01_machine_learning_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/01_machine_learning_paper_1.jpg"
 },
 {
  "file": "02_Machine_Learning_Paper_2.pdf",
  "field": "Machine Learning",
  "title": "Explainable Machine Learning for Credit Risk Assessment",
  "abstract": "This paper examines transparent credit risk estimation within the broader field of machine learning. The discussion centers on applicant income, repayment history, debt obligations, and account activity. The issue matters to lenders and applicants because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between transparent credit risk estimation and practical outcomes. The paper uses interpretable models alongside conventional predictive baselines as its principal analytical approach. It considers default probability and explanation quality as the main dimensions for evaluating the subject. The analysis places particular emphasis on model training, validation data, feature engineering, and deployment monitoring. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how transparent credit risk estimation can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with transparent credit risk estimation. It explains why applicant income, repayment history, debt obligations, and account activity are relevant to the research problem. Attention is given to the needs of lenders and applicants. The selected approach, interpretable models alongside conventional predictive baselines, provides a consistent structure for examining the available concepts. Evaluation is framed through default probability and explanation quality. The paper considers potential benefits such as fairer review processes and accountable lending decisions. At the same time, it recognizes limitations involving historical bias, incomplete records, and changing economic conditions. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding transparent credit risk estimation.",
  "tags": [
   "explainable",
   "machine",
   "learning",
   "credit"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/02_machine_learning_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/02_machine_learning_paper_2.jpg"
 },
 {
  "file": "03_Machine_Learning_Paper_3.pdf",
  "field": "Machine Learning",
  "title": "Machine Learning for Early Detection of Crop Disease",
  "abstract": "This paper examines plant disease identification from field observations within the broader field of machine learning. The discussion centers on leaf images, weather conditions, soil information, and crop history. The issue matters to farmers and agricultural advisers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between plant disease identification from field observations and practical outcomes. The paper uses image classification combined with contextual field data as its principal analytical approach. It considers classification accuracy and early detection time as the main dimensions for evaluating the subject. The analysis places particular emphasis on model training, validation data, feature engineering, and deployment monitoring. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how plant disease identification from field observations can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with plant disease identification from field observations. It explains why leaf images, weather conditions, soil information, and crop history are relevant to the research problem. Attention is given to the needs of farmers and agricultural advisers. The selected approach, image classification combined with contextual field data, provides a consistent structure for examining the available concepts. Evaluation is framed through classification accuracy and early detection time. The paper considers potential benefits such as timely treatment and reduced crop losses. At the same time, it recognizes limitations involving lighting variation, limited labeled images, and regional disease differences. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding plant disease identification from field observations.",
  "tags": [
   "machine",
   "learning",
   "early",
   "detection"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/03_machine_learning_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/03_machine_learning_paper_3.jpg"
 },
 {
  "file": "04_Machine_Learning_Paper_4.pdf",
  "field": "Machine Learning",
  "title": "Personalized Learning Recommendations Using Machine Learning",
  "abstract": "This paper examines adaptive educational content recommendations within the broader field of machine learning. The discussion centers on assessment results, learning pace, topic mastery, and engagement records. The issue matters to students and instructors because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between adaptive educational content recommendations and practical outcomes. The paper uses a recommendation model that updates from learner progress as its principal analytical approach. It considers recommendation relevance and learning progress as the main dimensions for evaluating the subject. The analysis places particular emphasis on model training, validation data, feature engineering, and deployment monitoring. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how adaptive educational content recommendations can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with adaptive educational content recommendations. It explains why assessment results, learning pace, topic mastery, and engagement records are relevant to the research problem. Attention is given to the needs of students and instructors. The selected approach, a recommendation model that updates from learner progress, provides a consistent structure for examining the available concepts. Evaluation is framed through recommendation relevance and learning progress. The paper considers potential benefits such as targeted practice and more responsive instruction. At the same time, it recognizes limitations involving privacy, cold-start learners, and uneven access to devices. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding adaptive educational content recommendations.",
  "tags": [
   "personalized",
   "learning",
   "recommendations",
   "machine"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/04_machine_learning_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/04_machine_learning_paper_4.jpg"
 },
 {
  "file": "05_Machine_Learning_Paper_5.pdf",
  "field": "Machine Learning",
  "title": "Detecting Network Intrusions with Machine Learning",
  "abstract": "This paper examines network intrusion detection within the broader field of machine learning. The discussion centers on network flows, connection duration, packet statistics, and alert histories. The issue matters to security analysts and network administrators because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between network intrusion detection and practical outcomes. The paper uses anomaly detection and supervised traffic classification as its principal analytical approach. It considers detection rate and false alarm frequency as the main dimensions for evaluating the subject. The analysis places particular emphasis on model training, validation data, feature engineering, and deployment monitoring. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how network intrusion detection can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with network intrusion detection. It explains why network flows, connection duration, packet statistics, and alert histories are relevant to the research problem. Attention is given to the needs of security analysts and network administrators. The selected approach, anomaly detection and supervised traffic classification, provides a consistent structure for examining the available concepts. Evaluation is framed through detection rate and false alarm frequency. The paper considers potential benefits such as faster triage and stronger network monitoring. At the same time, it recognizes limitations involving evolving attack patterns, encrypted traffic, and imbalanced datasets. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding network intrusion detection.",
  "tags": [
   "detecting",
   "network",
   "intrusions",
   "machine"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/05_machine_learning_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/05_machine_learning_paper_5.jpg"
 },
 {
  "file": "06_Astrophysics_Paper_1.pdf",
  "field": "Astrophysics",
  "title": "The Role of Dark Matter in Galaxy Rotation",
  "abstract": "This paper examines the relationship between galactic rotation and unseen mass within the broader field of astrophysics. The discussion centers on orbital velocities, galactic radius, luminous matter, and gravitational models. The issue matters to astronomers studying galaxy dynamics because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between galactic rotation and unseen mass and practical outcomes. The paper uses comparison of observed rotation curves with theoretical mass distributions as its principal analytical approach. It considers velocity profiles and inferred mass distribution as the main dimensions for evaluating the subject. The analysis places particular emphasis on observational evidence, physical theory, telescope instrumentation, and uncertainty estimation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between galactic rotation and unseen mass can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between galactic rotation and unseen mass. It explains why orbital velocities, galactic radius, luminous matter, and gravitational models are relevant to the research problem. Attention is given to the needs of astronomers studying galaxy dynamics. The selected approach, comparison of observed rotation curves with theoretical mass distributions, provides a consistent structure for examining the available concepts. Evaluation is framed through velocity profiles and inferred mass distribution. The paper considers potential benefits such as constraints on models of galactic structure. At the same time, it recognizes limitations involving measurement uncertainty and competing explanations for gravitational observations. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between galactic rotation and unseen mass.",
  "tags": [
   "role",
   "dark",
   "matter",
   "galaxy"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/06_astrophysics_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/06_astrophysics_paper_1.jpg"
 },
 {
  "file": "07_Astrophysics_Paper_2.pdf",
  "field": "Astrophysics",
  "title": "Exoplanet Atmospheres and the Search for Biosignatures",
  "abstract": "This paper examines the characterization of exoplanet atmospheres within the broader field of astrophysics. The discussion centers on transit spectra, atmospheric absorption features, stellar activity, and planetary temperature. The issue matters to exoplanet researchers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the characterization of exoplanet atmospheres and practical outcomes. The paper uses spectroscopic interpretation supported by atmospheric models as its principal analytical approach. It considers molecular detection confidence and atmospheric composition as the main dimensions for evaluating the subject. The analysis places particular emphasis on observational evidence, physical theory, telescope instrumentation, and uncertainty estimation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the characterization of exoplanet atmospheres can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the characterization of exoplanet atmospheres. It explains why transit spectra, atmospheric absorption features, stellar activity, and planetary temperature are relevant to the research problem. Attention is given to the needs of exoplanet researchers. The selected approach, spectroscopic interpretation supported by atmospheric models, provides a consistent structure for examining the available concepts. Evaluation is framed through molecular detection confidence and atmospheric composition. The paper considers potential benefits such as better prioritization of potentially habitable worlds. At the same time, it recognizes limitations involving instrument sensitivity, stellar contamination, and ambiguous chemical signals. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the characterization of exoplanet atmospheres.",
  "tags": [
   "exoplanet",
   "atmospheres",
   "search",
   "biosignatures"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/07_astrophysics_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/07_astrophysics_paper_2.jpg"
 },
 {
  "file": "08_Astrophysics_Paper_3.pdf",
  "field": "Astrophysics",
  "title": "Gravitational Waves as Probes of Compact Objects",
  "abstract": "This paper examines information carried by gravitational-wave signals within the broader field of astrophysics. The discussion centers on waveform shape, frequency evolution, source distance, and detector noise. The issue matters to gravitational-wave observatories because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between information carried by gravitational-wave signals and practical outcomes. The paper uses signal analysis and comparison with numerical-relativity predictions as its principal analytical approach. It considers parameter uncertainty and source classification as the main dimensions for evaluating the subject. The analysis places particular emphasis on observational evidence, physical theory, telescope instrumentation, and uncertainty estimation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how information carried by gravitational-wave signals can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with information carried by gravitational-wave signals. It explains why waveform shape, frequency evolution, source distance, and detector noise are relevant to the research problem. Attention is given to the needs of gravitational-wave observatories. The selected approach, signal analysis and comparison with numerical-relativity predictions, provides a consistent structure for examining the available concepts. Evaluation is framed through parameter uncertainty and source classification. The paper considers potential benefits such as improved understanding of black holes and neutron stars. At the same time, it recognizes limitations involving detector sensitivity, waveform assumptions, and limited event counts. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding information carried by gravitational-wave signals.",
  "tags": [
   "gravitational",
   "waves",
   "probes",
   "compact"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154727/arxiv/08_astrophysics_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/08_astrophysics_paper_3.jpg"
 },
 {
  "file": "09_Astrophysics_Paper_4.pdf",
  "field": "Astrophysics",
  "title": "Star Formation in Molecular Clouds",
  "abstract": "This paper examines the physical conditions that initiate star formation within the broader field of astrophysics. The discussion centers on gas density, temperature, turbulence, magnetic fields, and radiation. The issue matters to researchers studying interstellar clouds because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the physical conditions that initiate star formation and practical outcomes. The paper uses multiwavelength observations interpreted through physical models as its principal analytical approach. It considers cloud structure and indicators of gravitational collapse as the main dimensions for evaluating the subject. The analysis places particular emphasis on observational evidence, physical theory, telescope instrumentation, and uncertainty estimation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the physical conditions that initiate star formation can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the physical conditions that initiate star formation. It explains why gas density, temperature, turbulence, magnetic fields, and radiation are relevant to the research problem. Attention is given to the needs of researchers studying interstellar clouds. The selected approach, multiwavelength observations interpreted through physical models, provides a consistent structure for examining the available concepts. Evaluation is framed through cloud structure and indicators of gravitational collapse. The paper considers potential benefits such as insight into the origins of stellar populations. At the same time, it recognizes limitations involving dust obscuration, distance uncertainty, and complex cloud dynamics. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the physical conditions that initiate star formation.",
  "tags": [
   "star",
   "formation",
   "molecular",
   "clouds"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/09_astrophysics_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/09_astrophysics_paper_4.jpg"
 },
 {
  "file": "10_Astrophysics_Paper_5.pdf",
  "field": "Astrophysics",
  "title": "Black Hole Accretion and High-Energy Emission",
  "abstract": "This paper examines the conversion of gravitational energy into radiation near black holes within the broader field of astrophysics. The discussion centers on accretion rate, disk temperature, magnetic fields, and emitted spectra. The issue matters to high-energy astrophysicists because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the conversion of gravitational energy into radiation near black holes and practical outcomes. The paper uses theoretical accretion models compared with multiwavelength observations as its principal analytical approach. It considers spectral features and variability timescales as the main dimensions for evaluating the subject. The analysis places particular emphasis on observational evidence, physical theory, telescope instrumentation, and uncertainty estimation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the conversion of gravitational energy into radiation near black holes can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the conversion of gravitational energy into radiation near black holes. It explains why accretion rate, disk temperature, magnetic fields, and emitted spectra are relevant to the research problem. Attention is given to the needs of high-energy astrophysicists. The selected approach, theoretical accretion models compared with multiwavelength observations, provides a consistent structure for examining the available concepts. Evaluation is framed through spectral features and variability timescales. The paper considers potential benefits such as understanding of energetic processes around compact objects. At the same time, it recognizes limitations involving relativistic complexity, variable sources, and incomplete observational coverage. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the conversion of gravitational energy into radiation near black holes.",
  "tags": [
   "black",
   "hole",
   "accretion",
   "high"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/10_astrophysics_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/10_astrophysics_paper_5.jpg"
 },
 {
  "file": "11_Molecular_Biology_Paper_1.pdf",
  "field": "Molecular Biology",
  "title": "Gene Regulation and Cellular Response to Stress",
  "abstract": "This paper examines how cells regulate gene expression during stress within the broader field of molecular biology. The discussion centers on messenger RNA levels, transcription factors, signaling proteins, and stress exposure. The issue matters to molecular biologists because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between how cells regulate gene expression during stress and practical outcomes. The paper uses gene-expression profiling combined with targeted molecular assays as its principal analytical approach. It considers expression changes and pathway activity as the main dimensions for evaluating the subject. The analysis places particular emphasis on molecular mechanisms, experimental controls, biological samples, and reproducibility. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how how cells regulate gene expression during stress can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with how cells regulate gene expression during stress. It explains why messenger RNA levels, transcription factors, signaling proteins, and stress exposure are relevant to the research problem. Attention is given to the needs of molecular biologists. The selected approach, gene-expression profiling combined with targeted molecular assays, provides a consistent structure for examining the available concepts. Evaluation is framed through expression changes and pathway activity. The paper considers potential benefits such as identification of cellular adaptation mechanisms. At the same time, it recognizes limitations involving cell-type variation, experimental conditions, and indirect regulatory effects. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding how cells regulate gene expression during stress.",
  "tags": [
   "gene",
   "regulation",
   "cellular",
   "response"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/11_molecular_biology_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/11_molecular_biology_paper_1.jpg"
 },
 {
  "file": "12_Molecular_Biology_Paper_2.pdf",
  "field": "Molecular Biology",
  "title": "CRISPR-Based Functional Analysis of Disease-Associated Genes",
  "abstract": "This paper examines the function of selected disease-associated genes within the broader field of molecular biology. The discussion centers on gene variants, edited cell lines, protein abundance, and cellular phenotypes. The issue matters to biomedical researchers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the function of selected disease-associated genes and practical outcomes. The paper uses controlled gene editing followed by molecular and phenotypic validation as its principal analytical approach. It considers editing efficiency and phenotype changes as the main dimensions for evaluating the subject. The analysis places particular emphasis on molecular mechanisms, experimental controls, biological samples, and reproducibility. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the function of selected disease-associated genes can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the function of selected disease-associated genes. It explains why gene variants, edited cell lines, protein abundance, and cellular phenotypes are relevant to the research problem. Attention is given to the needs of biomedical researchers. The selected approach, controlled gene editing followed by molecular and phenotypic validation, provides a consistent structure for examining the available concepts. Evaluation is framed through editing efficiency and phenotype changes. The paper considers potential benefits such as stronger evidence about gene function and disease mechanisms. At the same time, it recognizes limitations involving off-target edits, cell-line limitations, and context-dependent effects. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the function of selected disease-associated genes.",
  "tags": [
   "crispr",
   "functional",
   "disease",
   "associated"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/12_molecular_biology_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/12_molecular_biology_paper_2.jpg"
 },
 {
  "file": "13_Molecular_Biology_Paper_3.pdf",
  "field": "Molecular Biology",
  "title": "Mitochondrial DNA Variation and Cellular Energy",
  "abstract": "This paper examines the relationship between mitochondrial genetic variation and energy production within the broader field of molecular biology. The discussion centers on mitochondrial sequence variation, respiration, ATP production, and oxidative stress. The issue matters to cell and molecular biology researchers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between mitochondrial genetic variation and energy production and practical outcomes. The paper uses sequence analysis paired with cellular energy measurements as its principal analytical approach. It considers respiratory performance and ATP-related indicators as the main dimensions for evaluating the subject. The analysis places particular emphasis on molecular mechanisms, experimental controls, biological samples, and reproducibility. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between mitochondrial genetic variation and energy production can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between mitochondrial genetic variation and energy production. It explains why mitochondrial sequence variation, respiration, ATP production, and oxidative stress are relevant to the research problem. Attention is given to the needs of cell and molecular biology researchers. The selected approach, sequence analysis paired with cellular energy measurements, provides a consistent structure for examining the available concepts. Evaluation is framed through respiratory performance and ATP-related indicators. The paper considers potential benefits such as insight into variation in cellular energy metabolism. At the same time, it recognizes limitations involving heteroplasmy, tissue differences, and environmental influences. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between mitochondrial genetic variation and energy production.",
  "tags": [
   "mitochondrial",
   "variation",
   "cellular",
   "energy"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/13_molecular_biology_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/13_molecular_biology_paper_3.jpg"
 },
 {
  "file": "14_Molecular_Biology_Paper_4.pdf",
  "field": "Molecular Biology",
  "title": "Protein Folding and the Cellular Quality-Control System",
  "abstract": "This paper examines the maintenance of correctly folded proteins within the broader field of molecular biology. The discussion centers on protein structure, chaperone activity, aggregation, and degradation pathways. The issue matters to molecular and structural biologists because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the maintenance of correctly folded proteins and practical outcomes. The paper uses review of biochemical experiments and structural evidence as its principal analytical approach. It considers folding stability and protein aggregation as the main dimensions for evaluating the subject. The analysis places particular emphasis on molecular mechanisms, experimental controls, biological samples, and reproducibility. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the maintenance of correctly folded proteins can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the maintenance of correctly folded proteins. It explains why protein structure, chaperone activity, aggregation, and degradation pathways are relevant to the research problem. Attention is given to the needs of molecular and structural biologists. The selected approach, review of biochemical experiments and structural evidence, provides a consistent structure for examining the available concepts. Evaluation is framed through folding stability and protein aggregation. The paper considers potential benefits such as understanding of cellular protection against protein damage. At the same time, it recognizes limitations involving dynamic protein states, model-system differences, and measurement limits. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the maintenance of correctly folded proteins.",
  "tags": [
   "protein",
   "folding",
   "cellular",
   "quality"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/14_molecular_biology_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/14_molecular_biology_paper_4.jpg"
 },
 {
  "file": "15_Molecular_Biology_Paper_5.pdf",
  "field": "Molecular Biology",
  "title": "MicroRNA Networks in Cancer Cell Behavior",
  "abstract": "This paper examines the regulatory role of microRNAs in cancer-related pathways within the broader field of molecular biology. The discussion centers on microRNA abundance, target messenger RNAs, signaling proteins, and cell behavior. The issue matters to cancer biology researchers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the regulatory role of microRNAs in cancer-related pathways and practical outcomes. The paper uses expression analysis and target-validation approaches as its principal analytical approach. It considers target regulation and cellular response as the main dimensions for evaluating the subject. The analysis places particular emphasis on molecular mechanisms, experimental controls, biological samples, and reproducibility. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the regulatory role of microRNAs in cancer-related pathways can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the regulatory role of microRNAs in cancer-related pathways. It explains why microRNA abundance, target messenger RNAs, signaling proteins, and cell behavior are relevant to the research problem. Attention is given to the needs of cancer biology researchers. The selected approach, expression analysis and target-validation approaches, provides a consistent structure for examining the available concepts. Evaluation is framed through target regulation and cellular response. The paper considers potential benefits such as candidate pathways for future diagnostic and therapeutic research. At the same time, it recognizes limitations involving tumor heterogeneity, indirect targets, and variation among cancer types. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the regulatory role of microRNAs in cancer-related pathways.",
  "tags": [
   "microrna",
   "networks",
   "cancer",
   "cell"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/15_molecular_biology_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/15_molecular_biology_paper_5.jpg"
 },
 {
  "file": "16_Cryptography_Paper_1.pdf",
  "field": "Cryptography",
  "title": "Post-Quantum Cryptography for Secure Data Exchange",
  "abstract": "This paper examines the transition toward cryptographic systems resistant to quantum attacks within the broader field of cryptography. The discussion centers on key sizes, ciphertext sizes, computation time, and communication overhead. The issue matters to system architects and security engineers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the transition toward cryptographic systems resistant to quantum attacks and practical outcomes. The paper uses comparative analysis of post-quantum algorithm families as its principal analytical approach. It considers security assumptions and implementation performance as the main dimensions for evaluating the subject. The analysis places particular emphasis on threat models, cryptographic primitives, key management, and implementation security. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the transition toward cryptographic systems resistant to quantum attacks can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the transition toward cryptographic systems resistant to quantum attacks. It explains why key sizes, ciphertext sizes, computation time, and communication overhead are relevant to the research problem. Attention is given to the needs of system architects and security engineers. The selected approach, comparative analysis of post-quantum algorithm families, provides a consistent structure for examining the available concepts. Evaluation is framed through security assumptions and implementation performance. The paper considers potential benefits such as migration planning for long-lived sensitive information. At the same time, it recognizes limitations involving standardization changes, implementation flaws, and resource constraints. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the transition toward cryptographic systems resistant to quantum attacks.",
  "tags": [
   "post",
   "quantum",
   "cryptography",
   "secure"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/16_cryptography_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/16_cryptography_paper_1.jpg"
 },
 {
  "file": "17_Cryptography_Paper_2.pdf",
  "field": "Cryptography",
  "title": "Elliptic Curve Cryptography in Resource-Constrained Devices",
  "abstract": "This paper examines efficient public-key cryptography on devices with limited resources within the broader field of cryptography. The discussion centers on processor cycles, memory use, key handling, and energy consumption. The issue matters to embedded-system developers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between efficient public-key cryptography on devices with limited resources and practical outcomes. The paper uses benchmarking of elliptic-curve operations under controlled device conditions as its principal analytical approach. It considers execution time and resource utilization as the main dimensions for evaluating the subject. The analysis places particular emphasis on threat models, cryptographic primitives, key management, and implementation security. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how efficient public-key cryptography on devices with limited resources can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with efficient public-key cryptography on devices with limited resources. It explains why processor cycles, memory use, key handling, and energy consumption are relevant to the research problem. Attention is given to the needs of embedded-system developers. The selected approach, benchmarking of elliptic-curve operations under controlled device conditions, provides a consistent structure for examining the available concepts. Evaluation is framed through execution time and resource utilization. The paper considers potential benefits such as secure communication for constrained hardware. At the same time, it recognizes limitations involving side-channel exposure, device diversity, and implementation quality. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding efficient public-key cryptography on devices with limited resources.",
  "tags": [
   "elliptic",
   "curve",
   "cryptography",
   "resource"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/17_cryptography_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/17_cryptography_paper_2.jpg"
 },
 {
  "file": "18_Cryptography_Paper_3.pdf",
  "field": "Cryptography",
  "title": "Privacy-Preserving Data Analysis with Homomorphic Encryption",
  "abstract": "This paper examines computation on encrypted data without first exposing plaintext within the broader field of cryptography. The discussion centers on ciphertext expansion, operation depth, latency, and workload type. The issue matters to privacy engineers and data analysts because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between computation on encrypted data without first exposing plaintext and practical outcomes. The paper uses analysis of supported encrypted operations and performance trade-offs as its principal analytical approach. It considers privacy properties and computational overhead as the main dimensions for evaluating the subject. The analysis places particular emphasis on threat models, cryptographic primitives, key management, and implementation security. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how computation on encrypted data without first exposing plaintext can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with computation on encrypted data without first exposing plaintext. It explains why ciphertext expansion, operation depth, latency, and workload type are relevant to the research problem. Attention is given to the needs of privacy engineers and data analysts. The selected approach, analysis of supported encrypted operations and performance trade-offs, provides a consistent structure for examining the available concepts. Evaluation is framed through privacy properties and computational overhead. The paper considers potential benefits such as safer processing of sensitive datasets by external services. At the same time, it recognizes limitations involving high computational cost, limited operation support, and key management. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding computation on encrypted data without first exposing plaintext.",
  "tags": [
   "privacy",
   "preserving",
   "data",
   "homomorphic"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154728/arxiv/18_cryptography_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/18_cryptography_paper_3.jpg"
 },
 {
  "file": "19_Cryptography_Paper_4.pdf",
  "field": "Cryptography",
  "title": "Blockchain Authentication and Digital Signature Verification",
  "abstract": "This paper examines the use of digital signatures to authenticate transactions within the broader field of cryptography. The discussion centers on public keys, signature validity, transaction records, and verification time. The issue matters to blockchain developers and auditors because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the use of digital signatures to authenticate transactions and practical outcomes. The paper uses protocol-level examination of signing and verification workflows as its principal analytical approach. It considers authentication integrity and verification performance as the main dimensions for evaluating the subject. The analysis places particular emphasis on threat models, cryptographic primitives, key management, and implementation security. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the use of digital signatures to authenticate transactions can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the use of digital signatures to authenticate transactions. It explains why public keys, signature validity, transaction records, and verification time are relevant to the research problem. Attention is given to the needs of blockchain developers and auditors. The selected approach, protocol-level examination of signing and verification workflows, provides a consistent structure for examining the available concepts. Evaluation is framed through authentication integrity and verification performance. The paper considers potential benefits such as stronger transaction accountability. At the same time, it recognizes limitations involving private-key loss, software vulnerabilities, and user error. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the use of digital signatures to authenticate transactions.",
  "tags": [
   "blockchain",
   "authentication",
   "digital",
   "signature"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/19_cryptography_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/19_cryptography_paper_4.jpg"
 },
 {
  "file": "20_Cryptography_Paper_5.pdf",
  "field": "Cryptography",
  "title": "Secure Password Storage Through Modern Hashing",
  "abstract": "This paper examines the protection of stored credentials against offline guessing within the broader field of cryptography. The discussion centers on salt generation, work factors, hash verification, and password distributions. The issue matters to application developers and security administrators because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the protection of stored credentials against offline guessing and practical outcomes. The paper uses comparison of password-hashing configurations and threat scenarios as its principal analytical approach. It considers guessing resistance and verification cost as the main dimensions for evaluating the subject. The analysis places particular emphasis on threat models, cryptographic primitives, key management, and implementation security. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the protection of stored credentials against offline guessing can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the protection of stored credentials against offline guessing. It explains why salt generation, work factors, hash verification, and password distributions are relevant to the research problem. Attention is given to the needs of application developers and security administrators. The selected approach, comparison of password-hashing configurations and threat scenarios, provides a consistent structure for examining the available concepts. Evaluation is framed through guessing resistance and verification cost. The paper considers potential benefits such as safer credential storage practices. At the same time, it recognizes limitations involving weak user passwords, poor configuration, and compromised application servers. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the protection of stored credentials against offline guessing.",
  "tags": [
   "secure",
   "password",
   "storage",
   "modern"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/20_cryptography_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/20_cryptography_paper_5.jpg"
 },
 {
  "file": "21_Psychology_Paper_1.pdf",
  "field": "Psychology",
  "title": "Sleep Quality and Cognitive Performance Among University Students",
  "abstract": "This paper examines the association between sleep quality and cognitive functioning within the broader field of psychology. The discussion centers on sleep duration, perceived sleep quality, attention, memory, and study routines. The issue matters to university students and student-support staff because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the association between sleep quality and cognitive functioning and practical outcomes. The paper uses review of validated measures and a proposed correlational study design as its principal analytical approach. It considers sleep indicators and cognitive task performance as the main dimensions for evaluating the subject. The analysis places particular emphasis on behavioral measures, participant context, psychological theory, and ethical research practice. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the association between sleep quality and cognitive functioning can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the association between sleep quality and cognitive functioning. It explains why sleep duration, perceived sleep quality, attention, memory, and study routines are relevant to the research problem. Attention is given to the needs of university students and student-support staff. The selected approach, review of validated measures and a proposed correlational study design, provides a consistent structure for examining the available concepts. Evaluation is framed through sleep indicators and cognitive task performance. The paper considers potential benefits such as evidence-informed student wellness initiatives. At the same time, it recognizes limitations involving self-report bias, schedule differences, and confounding factors. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the association between sleep quality and cognitive functioning.",
  "tags": [
   "sleep",
   "quality",
   "cognitive",
   "performance"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/21_psychology_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/21_psychology_paper_1.jpg"
 },
 {
  "file": "22_Psychology_Paper_2.pdf",
  "field": "Psychology",
  "title": "Social Media Use and Self-Esteem in Adolescents",
  "abstract": "This paper examines the relationship between social media experiences and adolescent self-esteem within the broader field of psychology. The discussion centers on usage patterns, social comparison, feedback, and self-evaluation. The issue matters to adolescents, families, and educators because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between social media experiences and adolescent self-esteem and practical outcomes. The paper uses analysis of survey-based evidence and relevant psychological theories as its principal analytical approach. It considers patterns of use and self-esteem measures as the main dimensions for evaluating the subject. The analysis places particular emphasis on behavioral measures, participant context, psychological theory, and ethical research practice. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between social media experiences and adolescent self-esteem can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between social media experiences and adolescent self-esteem. It explains why usage patterns, social comparison, feedback, and self-evaluation are relevant to the research problem. Attention is given to the needs of adolescents, families, and educators. The selected approach, analysis of survey-based evidence and relevant psychological theories, provides a consistent structure for examining the available concepts. Evaluation is framed through patterns of use and self-esteem measures. The paper considers potential benefits such as more informed digital-wellbeing guidance. At the same time, it recognizes limitations involving platform differences, reverse causality, and individual variation. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between social media experiences and adolescent self-esteem.",
  "tags": [
   "social",
   "media",
   "self",
   "esteem"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/22_psychology_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/22_psychology_paper_2.jpg"
 },
 {
  "file": "23_Psychology_Paper_3.pdf",
  "field": "Psychology",
  "title": "Academic Stress and Coping Strategies in College",
  "abstract": "This paper examines how college students experience and manage academic stress within the broader field of psychology. The discussion centers on workload, deadlines, perceived control, social support, and coping behaviors. The issue matters to college students and academic advisers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between how college students experience and manage academic stress and practical outcomes. The paper uses a mixed-method framework combining stress scales and interviews as its principal analytical approach. It considers reported stress and coping strategy patterns as the main dimensions for evaluating the subject. The analysis places particular emphasis on behavioral measures, participant context, psychological theory, and ethical research practice. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how how college students experience and manage academic stress can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with how college students experience and manage academic stress. It explains why workload, deadlines, perceived control, social support, and coping behaviors are relevant to the research problem. Attention is given to the needs of college students and academic advisers. The selected approach, a mixed-method framework combining stress scales and interviews, provides a consistent structure for examining the available concepts. Evaluation is framed through reported stress and coping strategy patterns. The paper considers potential benefits such as targeted academic support and healthier coping practices. At the same time, it recognizes limitations involving sampling limitations, cultural context, and changing semester demands. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding how college students experience and manage academic stress.",
  "tags": [
   "academic",
   "stress",
   "coping",
   "strategies"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/23_psychology_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/23_psychology_paper_3.jpg"
 },
 {
  "file": "24_Psychology_Paper_4.pdf",
  "field": "Psychology",
  "title": "The Influence of Workplace Recognition on Employee Motivation",
  "abstract": "This paper examines the connection between recognition practices and work motivation within the broader field of psychology. The discussion centers on feedback frequency, perceived fairness, autonomy, and job engagement. The issue matters to employees and organizational leaders because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the connection between recognition practices and work motivation and practical outcomes. The paper uses review of motivation theories and a proposed workplace survey as its principal analytical approach. It considers motivation indicators and perceived recognition quality as the main dimensions for evaluating the subject. The analysis places particular emphasis on behavioral measures, participant context, psychological theory, and ethical research practice. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the connection between recognition practices and work motivation can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the connection between recognition practices and work motivation. It explains why feedback frequency, perceived fairness, autonomy, and job engagement are relevant to the research problem. Attention is given to the needs of employees and organizational leaders. The selected approach, review of motivation theories and a proposed workplace survey, provides a consistent structure for examining the available concepts. Evaluation is framed through motivation indicators and perceived recognition quality. The paper considers potential benefits such as more constructive employee recognition systems. At the same time, it recognizes limitations involving role differences, organizational culture, and self-report limitations. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the connection between recognition practices and work motivation.",
  "tags": [
   "influence",
   "workplace",
   "recognition",
   "employee"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/24_psychology_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/24_psychology_paper_4.jpg"
 },
 {
  "file": "25_Psychology_Paper_5.pdf",
  "field": "Psychology",
  "title": "Mindfulness Practice and Emotional Regulation",
  "abstract": "This paper examines the role of mindfulness practice in emotional regulation within the broader field of psychology. The discussion centers on attention to present experience, emotional awareness, and regulation strategies. The issue matters to psychology practitioners and adult participants because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the role of mindfulness practice in emotional regulation and practical outcomes. The paper uses synthesis of experimental and observational research designs as its principal analytical approach. It considers emotional regulation measures and practice frequency as the main dimensions for evaluating the subject. The analysis places particular emphasis on behavioral measures, participant context, psychological theory, and ethical research practice. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the role of mindfulness practice in emotional regulation can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the role of mindfulness practice in emotional regulation. It explains why attention to present experience, emotional awareness, and regulation strategies are relevant to the research problem. Attention is given to the needs of psychology practitioners and adult participants. The selected approach, synthesis of experimental and observational research designs, provides a consistent structure for examining the available concepts. Evaluation is framed through emotional regulation measures and practice frequency. The paper considers potential benefits such as informed evaluation of mindfulness-based programs. At the same time, it recognizes limitations involving intervention variation, participant expectations, and follow-up duration. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the role of mindfulness practice in emotional regulation.",
  "tags": [
   "mindfulness",
   "practice",
   "emotional",
   "regulation"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/25_psychology_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/25_psychology_paper_5.jpg"
 },
 {
  "file": "26_Urban_Planning_Paper_1.pdf",
  "field": "Urban Planning",
  "title": "Transit-Oriented Development and Neighborhood Accessibility",
  "abstract": "This paper examines the relationship between compact development and public transport access within the broader field of urban planning. The discussion centers on station proximity, land-use mix, pedestrian routes, and service frequency. The issue matters to planners, commuters, and local communities because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between compact development and public transport access and practical outcomes. The paper uses spatial accessibility analysis supported by land-use review as its principal analytical approach. It considers accessibility and connectivity indicators as the main dimensions for evaluating the subject. The analysis places particular emphasis on spatial evidence, land-use decisions, public participation, and long-term urban change. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between compact development and public transport access can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between compact development and public transport access. It explains why station proximity, land-use mix, pedestrian routes, and service frequency are relevant to the research problem. Attention is given to the needs of planners, commuters, and local communities. The selected approach, spatial accessibility analysis supported by land-use review, provides a consistent structure for examining the available concepts. Evaluation is framed through accessibility and connectivity indicators. The paper considers potential benefits such as more inclusive transport-oriented neighborhood planning. At the same time, it recognizes limitations involving property-market pressure, displacement risk, and uneven service quality. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between compact development and public transport access.",
  "tags": [
   "transit",
   "oriented",
   "development",
   "neighborhood"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/26_urban_planning_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/26_urban_planning_paper_1.jpg"
 },
 {
  "file": "27_Urban_Planning_Paper_2.pdf",
  "field": "Urban Planning",
  "title": "Urban Green Spaces and Public Health",
  "abstract": "This paper examines the contribution of parks and green corridors to urban wellbeing within the broader field of urban planning. The discussion centers on green-space access, vegetation cover, walking activity, and environmental exposure. The issue matters to urban residents and city planners because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the contribution of parks and green corridors to urban wellbeing and practical outcomes. The paper uses spatial assessment combined with review of public-health evidence as its principal analytical approach. It considers proximity, use patterns, and environmental indicators as the main dimensions for evaluating the subject. The analysis places particular emphasis on spatial evidence, land-use decisions, public participation, and long-term urban change. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the contribution of parks and green corridors to urban wellbeing can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the contribution of parks and green corridors to urban wellbeing. It explains why green-space access, vegetation cover, walking activity, and environmental exposure are relevant to the research problem. Attention is given to the needs of urban residents and city planners. The selected approach, spatial assessment combined with review of public-health evidence, provides a consistent structure for examining the available concepts. Evaluation is framed through proximity, use patterns, and environmental indicators. The paper considers potential benefits such as health-supportive open-space planning. At the same time, it recognizes limitations involving maintenance gaps, unequal distribution, and differences in park quality. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the contribution of parks and green corridors to urban wellbeing.",
  "tags": [
   "urban",
   "green",
   "spaces",
   "public"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154729/arxiv/27_urban_planning_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/27_urban_planning_paper_2.jpg"
 },
 {
  "file": "28_Urban_Planning_Paper_3.pdf",
  "field": "Urban Planning",
  "title": "Flood-Resilient Planning in Rapidly Growing Cities",
  "abstract": "This paper examines the integration of flood risk into urban development decisions within the broader field of urban planning. The discussion centers on rainfall intensity, drainage capacity, impervious surfaces, and settlement patterns. The issue matters to local governments and disaster-risk planners because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the integration of flood risk into urban development decisions and practical outcomes. The paper uses risk mapping and scenario-based land-use assessment as its principal analytical approach. It considers exposure, vulnerability, and drainage performance as the main dimensions for evaluating the subject. The analysis places particular emphasis on spatial evidence, land-use decisions, public participation, and long-term urban change. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the integration of flood risk into urban development decisions can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the integration of flood risk into urban development decisions. It explains why rainfall intensity, drainage capacity, impervious surfaces, and settlement patterns are relevant to the research problem. Attention is given to the needs of local governments and disaster-risk planners. The selected approach, risk mapping and scenario-based land-use assessment, provides a consistent structure for examining the available concepts. Evaluation is framed through exposure, vulnerability, and drainage performance. The paper considers potential benefits such as reduced flood impacts through coordinated planning. At the same time, it recognizes limitations involving uncertain rainfall projections, informal development, and data gaps. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the integration of flood risk into urban development decisions.",
  "tags": [
   "flood",
   "resilient",
   "planning",
   "rapidly"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/28_urban_planning_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/28_urban_planning_paper_3.jpg"
 },
 {
  "file": "29_Urban_Planning_Paper_4.pdf",
  "field": "Urban Planning",
  "title": "Affordable Housing and Inclusive Neighborhood Design",
  "abstract": "This paper examines the planning conditions that support access to affordable housing within the broader field of urban planning. The discussion centers on housing costs, transit access, public services, and neighborhood amenities. The issue matters to housing agencies, residents, and developers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the planning conditions that support access to affordable housing and practical outcomes. The paper uses policy and spatial analysis of housing-location options as its principal analytical approach. It considers housing affordability and access to essential services as the main dimensions for evaluating the subject. The analysis places particular emphasis on spatial evidence, land-use decisions, public participation, and long-term urban change. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the planning conditions that support access to affordable housing can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the planning conditions that support access to affordable housing. It explains why housing costs, transit access, public services, and neighborhood amenities are relevant to the research problem. Attention is given to the needs of housing agencies, residents, and developers. The selected approach, policy and spatial analysis of housing-location options, provides a consistent structure for examining the available concepts. Evaluation is framed through housing affordability and access to essential services. The paper considers potential benefits such as more equitable residential development. At the same time, it recognizes limitations involving land constraints, financing limits, and potential displacement. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the planning conditions that support access to affordable housing.",
  "tags": [
   "affordable",
   "housing",
   "inclusive",
   "neighborhood"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/29_urban_planning_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/29_urban_planning_paper_4.jpg"
 },
 {
  "file": "30_Urban_Planning_Paper_5.pdf",
  "field": "Urban Planning",
  "title": "Walkable Streets and Local Economic Activity",
  "abstract": "This paper examines the influence of pedestrian-friendly streets on neighborhood activity within the broader field of urban planning. The discussion centers on sidewalk continuity, crossings, shade, frontage, and pedestrian counts. The issue matters to small businesses, residents, and transport planners because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the influence of pedestrian-friendly streets on neighborhood activity and practical outcomes. The paper uses street audits and analysis of pedestrian-oriented design principles as its principal analytical approach. It considers walkability indicators and observed street activity as the main dimensions for evaluating the subject. The analysis places particular emphasis on spatial evidence, land-use decisions, public participation, and long-term urban change. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the influence of pedestrian-friendly streets on neighborhood activity can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the influence of pedestrian-friendly streets on neighborhood activity. It explains why sidewalk continuity, crossings, shade, frontage, and pedestrian counts are relevant to the research problem. Attention is given to the needs of small businesses, residents, and transport planners. The selected approach, street audits and analysis of pedestrian-oriented design principles, provides a consistent structure for examining the available concepts. Evaluation is framed through walkability indicators and observed street activity. The paper considers potential benefits such as safer and more active local commercial areas. At the same time, it recognizes limitations involving weather, seasonal demand, and differences in business type. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the influence of pedestrian-friendly streets on neighborhood activity.",
  "tags": [
   "walkable",
   "streets",
   "local",
   "economic"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/30_urban_planning_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/30_urban_planning_paper_5.jpg"
 },
 {
  "file": "31_Mathematics_Paper_1.pdf",
  "field": "Mathematics",
  "title": "Graph Theory Applications in Urban Transportation Networks",
  "abstract": "This paper examines the mathematical structure of transportation networks within the broader field of mathematics. The discussion centers on vertices, edges, route lengths, connectivity, and network capacity. The issue matters to mathematicians and transport analysts because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the mathematical structure of transportation networks and practical outcomes. The paper uses graph representation and path-analysis methods as its principal analytical approach. It considers connectivity and route efficiency as the main dimensions for evaluating the subject. The analysis places particular emphasis on definitions, assumptions, formal derivations, computational checks, and mathematical interpretation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the mathematical structure of transportation networks can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the mathematical structure of transportation networks. It explains why vertices, edges, route lengths, connectivity, and network capacity are relevant to the research problem. Attention is given to the needs of mathematicians and transport analysts. The selected approach, graph representation and path-analysis methods, provides a consistent structure for examining the available concepts. Evaluation is framed through connectivity and route efficiency. The paper considers potential benefits such as improved network evaluation and planning. At the same time, it recognizes limitations involving simplified network assumptions and changing travel demand. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the mathematical structure of transportation networks.",
  "tags": [
   "graph",
   "theory",
   "applications",
   "urban"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/31_mathematics_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/31_mathematics_paper_1.jpg"
 },
 {
  "file": "32_Mathematics_Paper_2.pdf",
  "field": "Mathematics",
  "title": "Numerical Methods for Solving Nonlinear Equations",
  "abstract": "This paper examines the accuracy and stability of numerical root-finding within the broader field of mathematics. The discussion centers on initial estimates, convergence rates, residuals, and stopping criteria. The issue matters to students and practitioners in applied mathematics because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the accuracy and stability of numerical root-finding and practical outcomes. The paper uses comparison of bisection, Newton-type, and secant approaches as its principal analytical approach. It considers convergence behavior and numerical error as the main dimensions for evaluating the subject. The analysis places particular emphasis on definitions, assumptions, formal derivations, computational checks, and mathematical interpretation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the accuracy and stability of numerical root-finding can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the accuracy and stability of numerical root-finding. It explains why initial estimates, convergence rates, residuals, and stopping criteria are relevant to the research problem. Attention is given to the needs of students and practitioners in applied mathematics. The selected approach, comparison of bisection, Newton-type, and secant approaches, provides a consistent structure for examining the available concepts. Evaluation is framed through convergence behavior and numerical error. The paper considers potential benefits such as better method selection for computational problems. At the same time, it recognizes limitations involving sensitivity to initial values and finite-precision arithmetic. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the accuracy and stability of numerical root-finding.",
  "tags": [
   "numerical",
   "methods",
   "solving",
   "nonlinear"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/32_mathematics_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/32_mathematics_paper_2.jpg"
 },
 {
  "file": "33_Mathematics_Paper_3.pdf",
  "field": "Mathematics",
  "title": "Probability Models for Communicating Uncertainty",
  "abstract": "This paper examines the use of probability distributions to represent uncertain events within the broader field of mathematics. The discussion centers on random variables, distribution parameters, expected values, and variance. The issue matters to analysts working with uncertain data because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the use of probability distributions to represent uncertain events and practical outcomes. The paper uses model formulation and comparison of probability distributions as its principal analytical approach. It considers fit, calibration, and uncertainty summaries as the main dimensions for evaluating the subject. The analysis places particular emphasis on definitions, assumptions, formal derivations, computational checks, and mathematical interpretation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the use of probability distributions to represent uncertain events can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the use of probability distributions to represent uncertain events. It explains why random variables, distribution parameters, expected values, and variance are relevant to the research problem. Attention is given to the needs of analysts working with uncertain data. The selected approach, model formulation and comparison of probability distributions, provides a consistent structure for examining the available concepts. Evaluation is framed through fit, calibration, and uncertainty summaries. The paper considers potential benefits such as clearer interpretation of risk and uncertain outcomes. At the same time, it recognizes limitations involving distributional assumptions and limited observations. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the use of probability distributions to represent uncertain events.",
  "tags": [
   "probability",
   "models",
   "communicating",
   "uncertainty"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/33_mathematics_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/33_mathematics_paper_3.jpg"
 },
 {
  "file": "34_Mathematics_Paper_4.pdf",
  "field": "Mathematics",
  "title": "Linear Algebra in Machine Learning Systems",
  "abstract": "This paper examines the role of vectors and matrices in learning algorithms within the broader field of mathematics. The discussion centers on feature matrices, vector spaces, matrix products, and decompositions. The issue matters to mathematics and computing students because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the role of vectors and matrices in learning algorithms and practical outcomes. The paper uses mathematical analysis of linear transformations used in learning as its principal analytical approach. It considers dimensionality and computational structure as the main dimensions for evaluating the subject. The analysis places particular emphasis on definitions, assumptions, formal derivations, computational checks, and mathematical interpretation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the role of vectors and matrices in learning algorithms can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the role of vectors and matrices in learning algorithms. It explains why feature matrices, vector spaces, matrix products, and decompositions are relevant to the research problem. Attention is given to the needs of mathematics and computing students. The selected approach, mathematical analysis of linear transformations used in learning, provides a consistent structure for examining the available concepts. Evaluation is framed through dimensionality and computational structure. The paper considers potential benefits such as stronger understanding of model computation. At the same time, it recognizes limitations involving high-dimensional complexity and numerical conditioning. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the role of vectors and matrices in learning algorithms.",
  "tags": [
   "linear",
   "algebra",
   "machine",
   "learning"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154730/arxiv/34_mathematics_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/34_mathematics_paper_4.jpg"
 },
 {
  "file": "35_Mathematics_Paper_5.pdf",
  "field": "Mathematics",
  "title": "Optimization Techniques for Resource Allocation",
  "abstract": "This paper examines the mathematical allocation of limited resources within the broader field of mathematics. The discussion centers on decision variables, objective functions, constraints, and feasible solutions. The issue matters to operations researchers and decision-makers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the mathematical allocation of limited resources and practical outcomes. The paper uses formulation of linear and nonlinear optimization models as its principal analytical approach. It considers objective value and constraint satisfaction as the main dimensions for evaluating the subject. The analysis places particular emphasis on definitions, assumptions, formal derivations, computational checks, and mathematical interpretation. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the mathematical allocation of limited resources can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the mathematical allocation of limited resources. It explains why decision variables, objective functions, constraints, and feasible solutions are relevant to the research problem. Attention is given to the needs of operations researchers and decision-makers. The selected approach, formulation of linear and nonlinear optimization models, provides a consistent structure for examining the available concepts. Evaluation is framed through objective value and constraint satisfaction. The paper considers potential benefits such as more transparent and efficient allocation decisions. At the same time, it recognizes limitations involving uncertain inputs, competing objectives, and model simplification. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the mathematical allocation of limited resources.",
  "tags": [
   "optimization",
   "techniques",
   "resource",
   "allocation"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/35_mathematics_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/35_mathematics_paper_5.jpg"
 },
 {
  "file": "36_Physics_Paper_1.pdf",
  "field": "Physics",
  "title": "Heat Transfer in Composite Building Materials",
  "abstract": "This paper examines the movement of thermal energy through layered materials within the broader field of physics. The discussion centers on thermal conductivity, layer thickness, surface temperature, and heat flux. The issue matters to building scientists and materials researchers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the movement of thermal energy through layered materials and practical outcomes. The paper uses analytical heat-transfer models and controlled measurement concepts as its principal analytical approach. It considers temperature distribution and heat-flow rate as the main dimensions for evaluating the subject. The analysis places particular emphasis on physical principles, measurable quantities, controlled conditions, and model limitations. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the movement of thermal energy through layered materials can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the movement of thermal energy through layered materials. It explains why thermal conductivity, layer thickness, surface temperature, and heat flux are relevant to the research problem. Attention is given to the needs of building scientists and materials researchers. The selected approach, analytical heat-transfer models and controlled measurement concepts, provides a consistent structure for examining the available concepts. Evaluation is framed through temperature distribution and heat-flow rate. The paper considers potential benefits such as better-informed material selection for thermal comfort. At the same time, it recognizes limitations involving boundary assumptions, moisture effects, and material aging. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the movement of thermal energy through layered materials.",
  "tags": [
   "heat",
   "transfer",
   "composite",
   "building"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/36_physics_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/36_physics_paper_1.jpg"
 },
 {
  "file": "37_Physics_Paper_2.pdf",
  "field": "Physics",
  "title": "Renewable Energy Conversion and Photovoltaic Efficiency",
  "abstract": "This paper examines the conversion of incident sunlight into electrical energy within the broader field of physics. The discussion centers on irradiance, cell temperature, spectral response, and electrical output. The issue matters to energy researchers and system designers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the conversion of incident sunlight into electrical energy and practical outcomes. The paper uses physical analysis of photovoltaic conversion and operating conditions as its principal analytical approach. It considers conversion efficiency and power output as the main dimensions for evaluating the subject. The analysis places particular emphasis on physical principles, measurable quantities, controlled conditions, and model limitations. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the conversion of incident sunlight into electrical energy can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the conversion of incident sunlight into electrical energy. It explains why irradiance, cell temperature, spectral response, and electrical output are relevant to the research problem. Attention is given to the needs of energy researchers and system designers. The selected approach, physical analysis of photovoltaic conversion and operating conditions, provides a consistent structure for examining the available concepts. Evaluation is framed through conversion efficiency and power output. The paper considers potential benefits such as improved photovoltaic system design. At the same time, it recognizes limitations involving weather variability, degradation, and installation conditions. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the conversion of incident sunlight into electrical energy.",
  "tags": [
   "renewable",
   "energy",
   "conversion",
   "photovoltaic"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/37_physics_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/37_physics_paper_2.jpg"
 },
 {
  "file": "38_Physics_Paper_3.pdf",
  "field": "Physics",
  "title": "Acoustic Wave Behavior in Enclosed Spaces",
  "abstract": "This paper examines the propagation and reflection of sound in rooms within the broader field of physics. The discussion centers on frequency, wavelength, absorption, reverberation, and room geometry. The issue matters to acoustics researchers and building designers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the propagation and reflection of sound in rooms and practical outcomes. The paper uses wave-based analysis and room-acoustic measurement principles as its principal analytical approach. It considers reverberation time and sound-pressure distribution as the main dimensions for evaluating the subject. The analysis places particular emphasis on physical principles, measurable quantities, controlled conditions, and model limitations. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the propagation and reflection of sound in rooms can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the propagation and reflection of sound in rooms. It explains why frequency, wavelength, absorption, reverberation, and room geometry are relevant to the research problem. Attention is given to the needs of acoustics researchers and building designers. The selected approach, wave-based analysis and room-acoustic measurement principles, provides a consistent structure for examining the available concepts. Evaluation is framed through reverberation time and sound-pressure distribution. The paper considers potential benefits such as more effective acoustic design. At the same time, it recognizes limitations involving furnishing changes, measurement placement, and irregular geometry. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the propagation and reflection of sound in rooms.",
  "tags": [
   "acoustic",
   "wave",
   "behavior",
   "enclosed"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/38_physics_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/38_physics_paper_3.jpg"
 },
 {
  "file": "39_Physics_Paper_4.pdf",
  "field": "Physics",
  "title": "Fluid Dynamics of Flow Through Narrow Channels",
  "abstract": "This paper examines the behavior of fluid moving through confined passages within the broader field of physics. The discussion centers on flow velocity, pressure difference, viscosity, and channel dimensions. The issue matters to mechanical and applied physicists because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the behavior of fluid moving through confined passages and practical outcomes. The paper uses continuity and momentum analysis across flow regimes as its principal analytical approach. It considers pressure drop and flow profile as the main dimensions for evaluating the subject. The analysis places particular emphasis on physical principles, measurable quantities, controlled conditions, and model limitations. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the behavior of fluid moving through confined passages can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the behavior of fluid moving through confined passages. It explains why flow velocity, pressure difference, viscosity, and channel dimensions are relevant to the research problem. Attention is given to the needs of mechanical and applied physicists. The selected approach, continuity and momentum analysis across flow regimes, provides a consistent structure for examining the available concepts. Evaluation is framed through pressure drop and flow profile. The paper considers potential benefits such as better prediction of channel-flow performance. At the same time, it recognizes limitations involving surface roughness, entrance effects, and non-ideal fluid behavior. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the behavior of fluid moving through confined passages.",
  "tags": [
   "fluid",
   "dynamics",
   "flow",
   "narrow"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/39_physics_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/39_physics_paper_4.jpg"
 },
 {
  "file": "40_Physics_Paper_5.pdf",
  "field": "Physics",
  "title": "Magnetic Materials and Their Hysteresis Behavior",
  "abstract": "This paper examines the response of magnetic materials to changing magnetic fields within the broader field of physics. The discussion centers on magnetic field strength, flux density, coercivity, and remanence. The issue matters to materials physicists and electrical engineers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the response of magnetic materials to changing magnetic fields and practical outcomes. The paper uses interpretation of magnetization curves and domain behavior as its principal analytical approach. It considers hysteresis-loop characteristics and energy loss as the main dimensions for evaluating the subject. The analysis places particular emphasis on physical principles, measurable quantities, controlled conditions, and model limitations. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the response of magnetic materials to changing magnetic fields can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the response of magnetic materials to changing magnetic fields. It explains why magnetic field strength, flux density, coercivity, and remanence are relevant to the research problem. Attention is given to the needs of materials physicists and electrical engineers. The selected approach, interpretation of magnetization curves and domain behavior, provides a consistent structure for examining the available concepts. Evaluation is framed through hysteresis-loop characteristics and energy loss. The paper considers potential benefits such as guidance for selecting magnetic materials. At the same time, it recognizes limitations involving temperature dependence, sample history, and material composition. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the response of magnetic materials to changing magnetic fields.",
  "tags": [
   "magnetic",
   "materials",
   "their",
   "hysteresis"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/40_physics_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/40_physics_paper_5.jpg"
 },
 {
  "file": "41_Economics_Paper_1.pdf",
  "field": "Economics",
  "title": "Inflation Expectations and Household Spending Decisions",
  "abstract": "This paper examines the influence of expected price changes on household consumption within the broader field of economics. The discussion centers on expected inflation, income, savings, prices, and durable purchases. The issue matters to households and economic policymakers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the influence of expected price changes on household consumption and practical outcomes. The paper uses review of economic theory and a proposed household survey design as its principal analytical approach. It considers spending intentions and expectation measures as the main dimensions for evaluating the subject. The analysis places particular emphasis on incentives, resource constraints, institutional conditions, and measurable economic outcomes. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the influence of expected price changes on household consumption can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the influence of expected price changes on household consumption. It explains why expected inflation, income, savings, prices, and durable purchases are relevant to the research problem. Attention is given to the needs of households and economic policymakers. The selected approach, review of economic theory and a proposed household survey design, provides a consistent structure for examining the available concepts. Evaluation is framed through spending intentions and expectation measures. The paper considers potential benefits such as better interpretation of consumption responses to inflation. At the same time, it recognizes limitations involving survey expectations, income heterogeneity, and external shocks. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the influence of expected price changes on household consumption.",
  "tags": [
   "inflation",
   "expectations",
   "household",
   "spending"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/41_economics_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/41_economics_paper_1.jpg"
 },
 {
  "file": "42_Economics_Paper_2.pdf",
  "field": "Economics",
  "title": "Microfinance and the Growth of Small Enterprises",
  "abstract": "This paper examines the relationship between access to small-scale finance and enterprise development within the broader field of economics. The discussion centers on loan access, interest costs, business revenue, employment, and repayment. The issue matters to microenterprise owners and development institutions because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between access to small-scale finance and enterprise development and practical outcomes. The paper uses comparative analysis of lending models and enterprise outcomes as its principal analytical approach. It considers business continuity and growth indicators as the main dimensions for evaluating the subject. The analysis places particular emphasis on incentives, resource constraints, institutional conditions, and measurable economic outcomes. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between access to small-scale finance and enterprise development can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between access to small-scale finance and enterprise development. It explains why loan access, interest costs, business revenue, employment, and repayment are relevant to the research problem. Attention is given to the needs of microenterprise owners and development institutions. The selected approach, comparative analysis of lending models and enterprise outcomes, provides a consistent structure for examining the available concepts. Evaluation is framed through business continuity and growth indicators. The paper considers potential benefits such as more effective financial inclusion programs. At the same time, it recognizes limitations involving selection effects, debt burden, and local market conditions. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between access to small-scale finance and enterprise development.",
  "tags": [
   "microfinance",
   "growth",
   "small",
   "enterprises"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/42_economics_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/42_economics_paper_2.jpg"
 },
 {
  "file": "43_Economics_Paper_3.pdf",
  "field": "Economics",
  "title": "Unemployment and Skills Mismatch in Emerging Labor Markets",
  "abstract": "This paper examines the role of skills mismatch in labor-market unemployment within the broader field of economics. The discussion centers on education, occupational requirements, vacancies, and worker experience. The issue matters to workers, employers, and labor policymakers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the role of skills mismatch in labor-market unemployment and practical outcomes. The paper uses labor-market analysis using occupation and skills frameworks as its principal analytical approach. It considers vacancy duration and qualification mismatch as the main dimensions for evaluating the subject. The analysis places particular emphasis on incentives, resource constraints, institutional conditions, and measurable economic outcomes. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the role of skills mismatch in labor-market unemployment can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the role of skills mismatch in labor-market unemployment. It explains why education, occupational requirements, vacancies, and worker experience are relevant to the research problem. Attention is given to the needs of workers, employers, and labor policymakers. The selected approach, labor-market analysis using occupation and skills frameworks, provides a consistent structure for examining the available concepts. Evaluation is framed through vacancy duration and qualification mismatch. The paper considers potential benefits such as more targeted training and employment policies. At the same time, it recognizes limitations involving informal work, incomplete vacancy data, and regional variation. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the role of skills mismatch in labor-market unemployment.",
  "tags": [
   "unemployment",
   "skills",
   "mismatch",
   "emerging"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/43_economics_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/43_economics_paper_3.jpg"
 },
 {
  "file": "44_Economics_Paper_4.pdf",
  "field": "Economics",
  "title": "Exchange Rate Volatility and International Trade",
  "abstract": "This paper examines the relationship between currency movements and cross-border trade within the broader field of economics. The discussion centers on exchange rates, export prices, import costs, and trade volumes. The issue matters to exporters, importers, and economic analysts because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the relationship between currency movements and cross-border trade and practical outcomes. The paper uses econometric framing of exchange-rate and trade relationships as its principal analytical approach. It considers trade volume and price sensitivity as the main dimensions for evaluating the subject. The analysis places particular emphasis on incentives, resource constraints, institutional conditions, and measurable economic outcomes. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the relationship between currency movements and cross-border trade can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the relationship between currency movements and cross-border trade. It explains why exchange rates, export prices, import costs, and trade volumes are relevant to the research problem. Attention is given to the needs of exporters, importers, and economic analysts. The selected approach, econometric framing of exchange-rate and trade relationships, provides a consistent structure for examining the available concepts. Evaluation is framed through trade volume and price sensitivity. The paper considers potential benefits such as better currency-risk planning. At the same time, it recognizes limitations involving global shocks, contract timing, and policy changes. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the relationship between currency movements and cross-border trade.",
  "tags": [
   "exchange",
   "rate",
   "volatility",
   "international"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154731/arxiv/44_economics_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/44_economics_paper_4.jpg"
 },
 {
  "file": "45_Economics_Paper_5.pdf",
  "field": "Economics",
  "title": "Public Infrastructure Investment and Regional Productivity",
  "abstract": "This paper examines the contribution of infrastructure spending to regional economic activity within the broader field of economics. The discussion centers on transport access, utility reliability, public capital, and regional output. The issue matters to public agencies and regional development planners because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the contribution of infrastructure spending to regional economic activity and practical outcomes. The paper uses review of growth theory and regional investment evidence as its principal analytical approach. It considers productivity and connectivity indicators as the main dimensions for evaluating the subject. The analysis places particular emphasis on incentives, resource constraints, institutional conditions, and measurable economic outcomes. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the contribution of infrastructure spending to regional economic activity can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the contribution of infrastructure spending to regional economic activity. It explains why transport access, utility reliability, public capital, and regional output are relevant to the research problem. Attention is given to the needs of public agencies and regional development planners. The selected approach, review of growth theory and regional investment evidence, provides a consistent structure for examining the available concepts. Evaluation is framed through productivity and connectivity indicators. The paper considers potential benefits such as more informed infrastructure prioritization. At the same time, it recognizes limitations involving long project timelines, spillover effects, and measurement challenges. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the contribution of infrastructure spending to regional economic activity.",
  "tags": [
   "public",
   "infrastructure",
   "investment",
   "regional"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/45_economics_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/45_economics_paper_5.jpg"
 },
 {
  "file": "46_Electrical_Engineering_Paper_1.pdf",
  "field": "Electrical Engineering",
  "title": "Smart Grid Monitoring Through Internet-Connected Sensors",
  "abstract": "This paper examines the use of connected sensors for monitoring electrical distribution within the broader field of electrical engineering. The discussion centers on voltage, current, frequency, power quality, and communication latency. The issue matters to utilities and power-system engineers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the use of connected sensors for monitoring electrical distribution and practical outcomes. The paper uses architecture analysis of sensor-based monitoring systems as its principal analytical approach. It considers measurement reliability and event-detection time as the main dimensions for evaluating the subject. The analysis places particular emphasis on circuit behavior, system requirements, measurement procedures, and engineering standards. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the use of connected sensors for monitoring electrical distribution can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the use of connected sensors for monitoring electrical distribution. It explains why voltage, current, frequency, power quality, and communication latency are relevant to the research problem. Attention is given to the needs of utilities and power-system engineers. The selected approach, architecture analysis of sensor-based monitoring systems, provides a consistent structure for examining the available concepts. Evaluation is framed through measurement reliability and event-detection time. The paper considers potential benefits such as improved visibility of distribution network conditions. At the same time, it recognizes limitations involving cybersecurity, interoperability, and communication failures. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the use of connected sensors for monitoring electrical distribution.",
  "tags": [
   "smart",
   "grid",
   "monitoring",
   "internet"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/46_electrical_engineering_paper_1.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/46_electrical_engineering_paper_1.jpg"
 },
 {
  "file": "47_Electrical_Engineering_Paper_2.pdf",
  "field": "Electrical Engineering",
  "title": "Power Quality Assessment in Commercial Buildings",
  "abstract": "This paper examines the evaluation of electrical power quality in commercial facilities within the broader field of electrical engineering. The discussion centers on voltage variation, harmonics, power factor, and transient events. The issue matters to facility engineers and electrical maintenance teams because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the evaluation of electrical power quality in commercial facilities and practical outcomes. The paper uses measurement-based assessment using established power-quality concepts as its principal analytical approach. It considers distortion levels and event frequency as the main dimensions for evaluating the subject. The analysis places particular emphasis on circuit behavior, system requirements, measurement procedures, and engineering standards. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the evaluation of electrical power quality in commercial facilities can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the evaluation of electrical power quality in commercial facilities. It explains why voltage variation, harmonics, power factor, and transient events are relevant to the research problem. Attention is given to the needs of facility engineers and electrical maintenance teams. The selected approach, measurement-based assessment using established power-quality concepts, provides a consistent structure for examining the available concepts. Evaluation is framed through distortion levels and event frequency. The paper considers potential benefits such as more reliable electrical operation and equipment protection. At the same time, it recognizes limitations involving load variability, instrument accuracy, and monitoring duration. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the evaluation of electrical power quality in commercial facilities.",
  "tags": [
   "power",
   "quality",
   "commercial",
   "buildings"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/47_electrical_engineering_paper_2.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/47_electrical_engineering_paper_2.jpg"
 },
 {
  "file": "48_Electrical_Engineering_Paper_3.pdf",
  "field": "Electrical Engineering",
  "title": "Energy-Efficient Motor Control for Industrial Applications",
  "abstract": "This paper examines the reduction of electrical energy use in motor-driven systems within the broader field of electrical engineering. The discussion centers on motor load, speed, torque, drive efficiency, and operating cycles. The issue matters to industrial engineers and plant managers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the reduction of electrical energy use in motor-driven systems and practical outcomes. The paper uses comparison of motor-control strategies and operating profiles as its principal analytical approach. It considers energy consumption and control response as the main dimensions for evaluating the subject. The analysis places particular emphasis on circuit behavior, system requirements, measurement procedures, and engineering standards. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the reduction of electrical energy use in motor-driven systems can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the reduction of electrical energy use in motor-driven systems. It explains why motor load, speed, torque, drive efficiency, and operating cycles are relevant to the research problem. Attention is given to the needs of industrial engineers and plant managers. The selected approach, comparison of motor-control strategies and operating profiles, provides a consistent structure for examining the available concepts. Evaluation is framed through energy consumption and control response. The paper considers potential benefits such as lower operating costs and improved process control. At the same time, it recognizes limitations involving capital cost, maintenance needs, and changing load profiles. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the reduction of electrical energy use in motor-driven systems.",
  "tags": [
   "energy",
   "efficient",
   "motor",
   "control"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/48_electrical_engineering_paper_3.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/48_electrical_engineering_paper_3.jpg"
 },
 {
  "file": "49_Electrical_Engineering_Paper_4.pdf",
  "field": "Electrical Engineering",
  "title": "Wireless Power Transfer for Low-Power Electronic Devices",
  "abstract": "This paper examines the transfer of electrical energy without direct conductive contact within the broader field of electrical engineering. The discussion centers on coil geometry, coupling, operating frequency, distance, and alignment. The issue matters to electronics engineers and device designers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the transfer of electrical energy without direct conductive contact and practical outcomes. The paper uses analysis of inductive transfer principles and system design parameters as its principal analytical approach. It considers transfer efficiency and delivered power as the main dimensions for evaluating the subject. The analysis places particular emphasis on circuit behavior, system requirements, measurement procedures, and engineering standards. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the transfer of electrical energy without direct conductive contact can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the transfer of electrical energy without direct conductive contact. It explains why coil geometry, coupling, operating frequency, distance, and alignment are relevant to the research problem. Attention is given to the needs of electronics engineers and device designers. The selected approach, analysis of inductive transfer principles and system design parameters, provides a consistent structure for examining the available concepts. Evaluation is framed through transfer efficiency and delivered power. The paper considers potential benefits such as more flexible charging for low-power devices. At the same time, it recognizes limitations involving alignment sensitivity, electromagnetic compatibility, and heat loss. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the transfer of electrical energy without direct conductive contact.",
  "tags": [
   "wireless",
   "power",
   "transfer",
   "electronic"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/49_electrical_engineering_paper_4.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/49_electrical_engineering_paper_4.jpg"
 },
 {
  "file": "50_Electrical_Engineering_Paper_5.pdf",
  "field": "Electrical Engineering",
  "title": "Fault Detection and Protection in Low-Voltage Systems",
  "abstract": "This paper examines the detection and isolation of faults in low-voltage installations within the broader field of electrical engineering. The discussion centers on fault current, protective-device ratings, circuit impedance, and trip time. The issue matters to electrical installers and protection engineers because it affects how evidence is interpreted and decisions are made. The main objective is to explain the relationship between the detection and isolation of faults in low-voltage installations and practical outcomes. The paper uses coordination analysis of protective devices and fault scenarios as its principal analytical approach. It considers clearing time and protection selectivity as the main dimensions for evaluating the subject. The analysis places particular emphasis on circuit behavior, system requirements, measurement procedures, and engineering standards. It also identifies conditions that may influence the reliability of conclusions. The discussion is organized around established concepts rather than unsupported claims of new experimental results. Overall, the paper clarifies how the detection and isolation of faults in low-voltage installations can be studied in a systematic and responsible manner. The scope of this paper is limited to the central mechanisms and applications associated with the detection and isolation of faults in low-voltage installations. It explains why fault current, protective-device ratings, circuit impedance, and trip time are relevant to the research problem. Attention is given to the needs of electrical installers and protection engineers. The selected approach, coordination analysis of protective devices and fault scenarios, provides a consistent structure for examining the available concepts. Evaluation is framed through clearing time and protection selectivity. The paper considers potential benefits such as safer and more dependable electrical installations. At the same time, it recognizes limitations involving incorrect installation, aging components, and changing circuit loads. These limitations are important when interpreting evidence or transferring findings to another setting. The paper therefore distinguishes well-supported principles from questions that require additional investigation. Its central contribution is a clear framework for understanding the detection and isolation of faults in low-voltage installations.",
  "tags": [
   "fault",
   "detection",
   "protection",
   "voltage"
  ],
  "pages": 4,
  "pdfUrl": "https://res.cloudinary.com/vo35jey5/image/upload/v1795154732/arxiv/50_electrical_engineering_paper_5.pdf",
  "coverUrl": "https://res.cloudinary.com/vo35jey5/image/upload/pg_1,w_600,f_jpg/arxiv/50_electrical_engineering_paper_5.jpg"
 }
]
PAPERS_JSON;

$papers = json_decode($papersJson, true);
if (!is_array($papers) || count($papers) !== 50) {
    fail('Manifest problem: expected 50 papers, got ' . (is_array($papers) ? count($papers) : 'invalid JSON'));
}
foreach ($papers as $i => $p) {
    foreach (['file', 'field', 'title', 'abstract', 'tags', 'pages', 'pdfUrl', 'coverUrl'] as $k) {
        if (!isset($p[$k]) || $p[$k] === '') fail("Manifest problem: paper #" . ($i + 1) . " is missing '$k'");
    }
}

// --- API key: --apikey, else your local firebase_config.dart ---------------
$apiKey = $apiKeyArg;
if ($apiKey === null) {
    $configPaths = [
        __DIR__ . DIRECTORY_SEPARATOR . 'lib' . DIRECTORY_SEPARATOR . 'firebase' . DIRECTORY_SEPARATOR . 'firebase_config.dart',
        getcwd() . DIRECTORY_SEPARATOR . 'lib' . DIRECTORY_SEPARATOR . 'firebase' . DIRECTORY_SEPARATOR . 'firebase_config.dart',
    ];
    foreach ($configPaths as $cp) {
        if (is_file($cp) && preg_match("/apiKey\s*[=:]\s*'([^']+)'/", file_get_contents($cp), $m)) {
            $apiKey = $m[1];
            break;
        }
    }
}
if (!$dryRun && ($apiKey === null || $apiKey === '' || str_starts_with($apiKey, 'TODO') || $apiKey === '<redacted>')) {
    out('Could not read a real apiKey from lib/firebase/firebase_config.dart.');
    out('Paste the web apiKey from Firebase console -> Project settings -> Your apps -> Web app:');
    $apiKey = prompt('apiKey: ');
    if ($apiKey === '') fail('No apiKey given.');
}

// --- sign in ------------------------------------------------------------------
$email = $dryRun ? ($emailArg ?? 'dry-run@example.com') : ($emailArg ?? prompt('Arxiv email: '));
if ($email === '') fail('No email given.');
if ($dryRun) {
    out('[dry-run] Would sign in as ' . $email . ' — no network calls in dry-run mode.');
    $idToken = 'dry-run-token';
    $uid = 'dry-run-uid';
    $username = 'Dry Run';
    $avatar = '';
    $institution = '';
} else {
    out('Password (it shows while you type — it stays on your PC, only used to sign in):');
    $password = prompt('Arxiv password: ');
    if ($password === '') fail('No password given.');
    [$code, $res, $raw] = httpJson('POST', IDENTITY_BASE . urlencode($apiKey), [
        'email' => $email, 'password' => $password, 'returnSecureToken' => true,
    ]);
    if ($code !== 200 || empty($res['idToken'])) {
        $msg = $res['error']['message'] ?? ('HTTP ' . $code . ' ' . substr((string) $raw, 0, 200));
        if (str_contains($msg, 'INVALID_LOGIN_CREDENTIALS') || str_contains($msg, 'INVALID_PASSWORD') || str_contains($msg, 'EMAIL_NOT_FOUND')) {
            fail('Sign-in failed: wrong email or password for this Arxiv account.');
        }
        if (str_contains($msg, 'API key not valid')) {
            fail('Sign-in failed: the Firebase web apiKey is not valid. Re-copy it from Firebase console -> Project settings -> Your apps -> Web app into lib/firebase/firebase_config.dart.');
        }
        fail('Sign-in failed: ' . $msg);
    }
    $idToken = $res['idToken'];
    $uid = $res['localId'];
    out('Signed in. Your user id: ' . $uid);

    // Your profile (username / avatar / institution shown on each paper).
    [$code, $res] = httpJson('GET', FIRESTORE_BASE . '/users/' . rawurlencode($uid), null, $idToken);
    $f = ($code === 200 && isset($res['fields'])) ? $res['fields'] : [];
    $username = $f['username']['stringValue'] ?? '';
    $avatar = $f['avatar']['stringValue'] ?? '';
    $institution = $f['institution']['stringValue'] ?? '';
    if ($username === '') $username = strstr($email, '@', true);
    out('Posting as: ' . $username . ($institution !== '' ? ' (' . $institution . ')' : ''));
}

// --- resume file --------------------------------------------------------------
$donePath = __DIR__ . DIRECTORY_SEPARATOR . 'seed_library_done.json';
$done = [];
if (is_file($donePath)) {
    $done = json_decode(file_get_contents($donePath), true) ?: [];
}
$today = date('Y-m-d');
$year = date('Y');
$baseTime = time();

$posted = 0; $skipped = 0; $failed = 0;
foreach ($papers as $i => $p) {
    $n = $i + 1;
    if (isset($done[$p['title']])) { $skipped++; continue; }

    // Newest first in the Library: paper 01 gets "now", each later paper
    // one minute older (the app sorts by submittedAt, newest first).
    $submittedAt = gmdate('Y-m-d\TH:i:s\Z', $baseTime - ($i * 60));

    $fields = [
        'title' => fsStr($p['title']),
        'author' => fsStr($username),
        'authorId' => fsStr($uid),
        'authorAvatar' => fsStr($avatar),
        'abstract' => fsStr($p['abstract']),
        'field' => fsStr($p['field']),
        'tags' => fsArr($p['tags']),
        'coverImage' => fsStr($p['coverUrl']),
        'publishedAt' => fsStr($today),
        'pages' => fsInt($p['pages']),
        'views' => fsInt(0),
        'institution' => fsStr($institution),
        'year' => fsStr($year),
        'status' => fsStr('pending'),
        'submittedAt' => fsTs($submittedAt),
        'pdfUrl' => fsStr($p['pdfUrl']),
    ];

    if ($dryRun) {
        if ($i === 0) {
            out('[dry-run] First paper create body (all 50 use this shape):');
            out(json_encode(['fields' => $fields], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        }
        $posted++;
        continue;
    }

    // 1) Create as pending (rules demand status == pending on create,
    //    authorId == your uid, and title/abstract/field/authorId/status).
    [$code, $res, $raw] = httpJson('POST', FIRESTORE_BASE . '/papers', ['fields' => $fields], $idToken);
    if ($code !== 200 || empty($res['name'])) {
        $failed++;
        out("[$n/50] FAILED to create: " . $p['title']);
        out('  -> HTTP ' . $code . ': ' . substr((string) ($res['error']['message'] ?? $raw), 0, 300));
        continue;
    }
    $docId = basename((string) $res['name']);

    // 2) Approve it right away (admin update; also stamps publishedAt).
    $patchUrl = FIRESTORE_BASE . '/papers/' . rawurlencode($docId)
        . '?updateMask.fieldPaths=status&updateMask.fieldPaths=publishedAt';
    [$code2, $res2, $raw2] = httpJson('PATCH', $patchUrl, ['fields' => [
        'status' => fsStr('approved'),
        'publishedAt' => fsStr($today),
    ]], $idToken);
    if ($code2 !== 200) {
        $failed++;
        out("[$n/50] Created but FAILED to approve: " . $p['title'] . " (doc $docId — approve it in the admin panel)");
        out('  -> HTTP ' . $code2 . ': ' . substr((string) ($res2['error']['message'] ?? $raw2), 0, 300));
        continue;
    }

    $done[$p['title']] = $docId;
    file_put_contents($donePath, json_encode($done, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    $posted++;
    out("[$n/50] OK: " . $p['title'] . "  (" . $p['field'] . ', doc ' . $docId . ')');
}

out('');
out("Done. Posted: $posted, skipped (already posted before): $skipped, failed: $failed.");
if ($dryRun) {
    out('Dry-run only — nothing was sent. Run without --dry-run to post for real.');
} elseif ($failed === 0) {
    out('All 50 papers are now in the Library. Open the app -> Library and pull to refresh.');
} else {
    out('Some papers failed — just run the script again, it skips the ones already posted.');
    exit(1);
}
