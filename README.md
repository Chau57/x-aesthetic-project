# X-Aesthetic: Interactive Photography Assistant & Aesthetic Education System

X-Aesthetic is an Edge-AI expert system designed to bridge the gap between deep learning aesthetic assessment and human photography education. Instead of acting as another automated, "black-box" photo editor that alters images behind the scenes, X-Aesthetic embraces a "learning-by-doing" philosophy. It allows users to shoot instinctively, analyzes their aesthetic and compositional mistakes against curated reference styles, and provides actionable, real-time feedback to help them naturally develop their artistic eye.

## Core Features

### 1. Pre-capture Live View Support

* **Dynamic Context Detection:** Runs a lightweight convolutional object detection model in the background at 3–5 FPS to identify the shooting context (e.g., portrait, landscape, macro, or architecture).
* **Smart Compositional Overlays:** Dynamically triggers custom-drawn guide grids (Rule of Thirds, Symmetry, or Leading Lines) based on the AI's contextual tags.
* **Horizon Stabilizer:** Monitors device gyroscope and accelerometer data to render an interactive balance indicator, preventing accidental tilted shots.

### 2. Post-capture Deep Diagnostics

* **Multi-Level Spatially Pooled (MLSP) Features:** Leverages an EfficientNet-B4 backbone combined with an MLSP pooling strategy. This processes the image at its native resolution and aspect ratio without aggressive cropping or warping, fully preserving the original geometric composition.
* **Multi-Attribute Assessment:** Simultaneously predicts 29 distinct aesthetic attributes spanning both artistic style (FlickrStyle) and structural composition (KU-PCP).
* **Self-Adaptive Hypernetwork:** Feeds the attribute embeddings into a Hypernetwork that dynamically computes and generates tailored weights for the final evaluation layer (`AestheticNet`). This ensures a portrait is evaluated on portrait standards, not landscape criteria.
* **Aesthetic Score Distribution:** Predicts a full probability distribution of the score instead of a single, rigid mean value, capturing the inherent subjectivity of art.

### 3. Visual & Textual Feedback Loop (XAI Engine)

* **Visual Attention Heatmaps (Grad-CAM):** Extracts feature maps from the final convolutional blocks of the backbone to generate a lightweight visual saliency map, showing users exactly where the visual weight of their shot lies.
* **Ghost Frame Overlay:** Computes optimal framing adjustments and generates a semi-transparent guide layer over the camera screen, allowing users to physically recompose and practice the shot on the spot.
* **Natural Language Critiques:** An explainable AI mapping engine catches attributes falling below specific thresholds and translates those numbers into clear technical advice (e.g., "The background is cluttered; try stepping closer to isolate your subject").

### 4. Progress Tracking & Analytics

* **Immutable Error Logging:** Employs a local NoSQL database to store historical evaluation profiles. Deletion is restricted to maintain a continuous time-series dataset of user mistakes.
* **Performance Dashboard:** Aggregates recurring structural flaws and visualizes user improvement curves over weeks and months via clean progress charts.

## Tech Stack

* **Mobile App Framework:** Flutter (Dart) — utilizes the Impeller/Skia engine for smooth 60–120 FPS UI rendering and native `CustomPainter` canvas layers.
* **Concurrency:** Flutter Isolates & Dart FFI — offloads heavy matrix operations, image resizing, and model inference to a background worker thread to prevent main UI thread stutters.
* **Local Storage:** Hive — a lightweight, lightning-fast NoSQL key-value database running directly in memory, ideal for saving complex nested Dart objects without boilerplate SQL joins.
* **Edge-AI Runtime:** TensorFlow Lite Interpreter — executes quantized, low-footprint model inference completely offline on the mobile hardware.
* **Training Stack:** PyTorch — handles backbone feature caching, Hypernetwork joint training, and post-training quantization pipelines.

## Repository Architecture (Monorepo)

The project is structured to keep the machine learning training codebase cleanly isolated from the mobile application codebase, allowing team members to develop in parallel without merge conflicts.

```text
x-aesthetic-project/
├── ai_training/                  # AI RESEARCH & TRAINING SUITE (PYTHON)
│   ├── models/                   # PyTorch definitions for AttributeNet, HyperNet, and AestheticNet
│   ├── scripts/                  
│   │   ├── extract_features.py   # Freezes the backbone and caches MLSP embeddings to disk
│   │   ├── train_hypernet.py     # Main training loop script for the adaptive target layers
│   │   └── export_tflite.py      # Handles INT8/FP16 post-training quantization to .tflite
│   └── requirements.txt          # Python environment dependencies
│
└── x_aesthetic_app/              # MOBILE APPLICATION SYSTEM (FLUTTER)
    ├── assets/models/            # Compiled assets (yolov8n.tflite, aesthetic_net.tflite)
    └── lib/                      
        ├── core/                 # Microkernel layer, Isolate dispatchers, Dart FFI, and Plugin Loader
        ├── services/ai/          # Async model loading, byte buffer allocation, and image prep
        ├── domain/               # Core business logic, AestheticResult schemas, and XAI Engine rules
        ├── data/                 # Hive data storage, type adapters, and immutable repositories
        └── presentation/         # UI view layers, camera streams, CustomPainter layers, and charts

```

## Core Mathematical Foundation

The system evaluates the deviation between the user's captured image and the target style profile by calculating the distance between their cumulative probability distributions using Earth Mover's Distance (EMD):

$$EMD(\hat{q}, q) = \left( \frac{1}{N} \sum_{k=1}^{N} |CDF_{\hat{q}}(k) - CDF_{q}(k)|^r \right)^{1/r}$$

Where:

* $\hat{q}$ represents the aesthetic score probability distribution predicted by the adaptive `AestheticNet`.
* $q$ represents the target canonical distribution of the chosen photographic style profile.
* $r$ is the distance norm factor (typically set to 1 or 2 for $L_1$ or $L_2$ optimization).

## Getting Started

### 1. Training Environment Setup

Navigate to the training directory, initialize your virtual environment, and install the required dependencies:

```bash
cd ai_training
python -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate
pip install -r requirements.txt

```

To optimize shared server resources, run the feature extraction script first to cache backbone embeddings. This prevents running the massive EfficientNet backbone through every single epoch:

```bash
python scripts/extract_features.py --data_dir /path/to/dataset
python scripts/train_hypernet.py
python scripts/export_tflite.py --output_dir ../x_aesthetic_app/assets/models/

```

### 2. Running the Mobile App

Ensure you have the latest Flutter SDK configured. Pull the dependencies, ensure your physical device or emulator is connected, and launch the application:

```bash
cd x_aesthetic_app
flutter pub get
flutter run

```
