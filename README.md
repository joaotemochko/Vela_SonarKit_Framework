# Lyra Godot Framework 🌌
**A Spatial Sonification and Telemetry Framework for 3D Accessibility.**

The Lyra Godot Framework is a specialized tool developed for the **Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)** and **Universidade do Vale do Itajaí (UNIVALI)**. It is designed to facilitate autonomous navigation for visually impaired users in virtual 3D environments by converting spatial topology into real-time auditory feedback.

## 🔬 Research Purpose

This framework was developed as part of research project in **Digital Games and Psychology**. Its primary objective is to investigate **Spatial Sonification** as a viable method for non-visual wayfinding.

The tool serves two main scientific goals:
1.  **Assistive Technology:** To provide a low-cost, open-source solution for creating accessible 3D digital games and educational environments.
2.  **Behavioral Analysis:** To capture high-precision telemetry (position, hesitation time, trajectory deviation) for **Environmental Psychology** studies. These metrics help validate whether auditory cues effectively reduce cognitive load and navigation errors in the absence of visual stimuli.

---

## 🚀 Key Features

* **Adaptive Auto-Injection:** Automatically scans the scene tree to attach audio emitters to `CollisionShape3D`, `Area3D`, or `MeshInstance3D` nodes.
* **Virtual Acoustic Pooling:** Optimized audio management that instances players at the scene root, allowing for high-density soundscapes with minimal performance overhead.
* **Dynamic Psychoacoustic Feedback:** Real-time modulation of volume and pitch based on proximity and interaction type (e.g., Obstacles vs. Goals).
* **Research-Grade Telemetry:** Integrated logging system that generates `.csv` files containing timestamps, event triggers, and precise 3D coordinates (X, Y, Z) for behavioral analysis.

## 🛠️ Installation & Setup

1.  Copy the `addons/Lyra_Framework` folder into your project's `res://addons/` directory.
2.  Enable the plugin in **Project Settings > Plugins**.
3.  The framework will automatically register the `LyraCore` singleton (if configured) or you can instance it manually within your emitters.
4.  Configure the `Radar` export variable on the `LyraEmitter` node to select which type of geometry to monitor.

---

**Authors:**
* João Antônio Temochko Andre - Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Johnata Souza Santicioli - Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Carolina André da Silva - Universidade do Vale do Itajaí (UNIVALI)

**Institutions:**
* Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Universidade do Vale do Itajaí (UNIVALI)
