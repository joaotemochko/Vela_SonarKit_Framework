# Lyra Godot Framework 🌌
**A Spatial Sonification and Telemetry Framework for 3D Accessibility.**

The **Lyra Godot Framework** is a specialized tool developed for the **Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)**. It is designed to facilitate autonomous navigation for visually impaired users in virtual 3D environments by converting spatial topology into real-time auditory feedback.



## 🚀 Key Features

* **Adaptive Auto-Injection**: Automatically scans the scene tree to attach audio emitters to `CollisionShape3D`, `Area3D`, or `MeshInstance3D` nodes using a configurable radar system.
* **Virtual Acoustic Pooling**: Optimized audio management that instances players at the scene root, allowing for high-density soundscapes with minimal performance overhead by reusing audio resources.
* **Dynamic Psychoacoustic Feedback**: Real-time modulation of volume and pitch based on proximity and interaction type (e.g., Obstacles vs. Goals), helping users build mental maps of the environment.
* **Research-Grade Telemetry**: Integrated logging system that generates `.csv` files containing timestamps, event triggers (ENTER/EXIT), and precise 3D coordinates (X, Y, Z) for behavioral analysis.
* **Fault Tolerance**: Built-in protection against crashes when tracked objects are removed from the scene tree (`queue_free()`).



## 🛠️ Technical Implementation

### Core Components
* **LyraCore**: A centralized singleton that manages the audio pool and logs all experimental data to the user's data folder (`user://`).
* **LyraEmitter**: The primary node placed in the environment. It detects nearby collision shapes and requests audio players from the Core only when the user is within range.

### Authors
* **João Antônio Temochko Andre** – Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP).
* **Johnata Souza Santicioli** – Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP).
* **Carolina André da Silva** – Universidade do Vale do Itajaí (UNIVALI).

## 📊 Data Analytics

The framework includes the **LyraAnalyser**, a Python-based utility to process research logs. This tool allows researchers to visualize how effectively a user navigated the 3D space using only auditory cues.

* **Trajectory Heatmaps**: Top-down visualization of the user's path compared to environmental obstacles.
* **Proximity History**: Analysis of auditory cue effectiveness and user reaction times.

```bash
# Install dependencies
pip install pandas matplotlib

# Run the analyzer and select your .csv log
python lyra_analyser.py

```bash
# Install dependencies
pip install pandas matplotlib

# Run the analyzer
python lyra_analyser.py
