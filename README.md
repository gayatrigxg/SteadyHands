SteadyHands

SteadyHands is an iOS application designed to detect and analyze hand tremors using real-time motion data and signal processing techniques. The app also provides motion stabilization to assist users in performing fine motor tasks such as drawing.

Features

* Real-time tremor detection using device motion sensors
* Frequency-based analysis of hand movement patterns
* Motion stabilization for smoother drawing and interaction
* Gallery (“Museum”) to showcase user creations
* Clean and accessible user interface

Tech Stack

* Swift
* iOS (Xcode)
* Core Motion (accelerometer and gyroscope)
* Signal Processing (frequency analysis, noise filtering)

How It Works

1. Captures hand movement using device sensors
2. Processes motion data in real time
3. Applies noise filtering to reduce random disturbances
4. Performs frequency analysis to identify tremor patterns
5. Applies stabilization techniques during drawing
6. Displays results and visual output to the user


Technical Approach

The application uses accelerometer and gyroscope data to track hand motion. The raw signal is processed to extract meaningful patterns:

* Noise filtering reduces unwanted fluctuations
* Frequency analysis identifies oscillatory tremor behavior
* Stabilization smooths unintended micro-movements

This allows the system to both detect tremors and assist users by improving interaction stability.


Accuracy & Limitations

SteadyHands is a non-clinical, assistive application.

* Tremor detection is based on sensor data and observed frequency patterns
* Accuracy depends on device hardware, user movement, and environmental conditions
* Results are indicative and not intended for medical diagnosis

The goal is to provide awareness and assistive support rather than clinical evaluation.


Design Story

A key feature of SteadyHands is the Museum, a gallery where users can view and preserve their creations.

This idea was inspired by conversations with individuals experiencing hand tremors who expressed the emotional difficulty of losing the ability to create art.

One user shared how they once enjoyed drawing and had always imagined seeing their work displayed in a gallery. Over time, due to reduced motor control, continuing this passion became challenging.

The Museum feature was designed to:

* Provide a sense of achievement
* Preserve user creations in a meaningful way
* Recreate the experience of showcasing artwork

By combining motion stabilization with a gallery-like presentation, SteadyHands aims to help users reconnect with their creativity and confidence.


Future Enhancements

* Machine learning-based tremor classification
* Historical tracking and progress analysis
* Integration with healthcare platforms
* Enhanced visualization and reporting


Author

Gayatri G
Computer Science Engineering Student | iOS Developer
