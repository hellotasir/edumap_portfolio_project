# EDUMAP — Flutter-Based Chat Application

**Project Type:** Mobile Application  
**Platform:** Android (Flutter)  
**Version:** 1.0.0


---

## Overview

Edumap is a group or 1 to 1 chat system application. It also help student and instructor/teacher to find location of their current place.

The system follows a **progressive interaction model**:

1. Discover known people (students/instructors)
2. Send friend requests to initiate connection
3. Communicate via real-time chat
4. Distance tracker for meetup


### Backend Stack

| Component     | Responsibility                                             |
| ------------- | ---------------------------------------------------------- |
| Supabase      | Storage for storing objects, Authentication for user identity and Database for keep payments history |
| Firebase      | Database for keep user activities in the app |
| Google Cloud  | Linked with Gemini, Firebase and Supabase |
| OpenStreetMap | Geolocation and map services |
| ZEGO CLOUD    | For voice and video call |
| Stripe | For subscription payment getway |
| SSL_COMMERZ | For subscription payment getway |
| Local Notification | For sending notification to the user |

## Key Features

### Social

- Friend request system
- Profile management

### Communication

- Real-time chat
- Media messaging
- Voice and Video Call

### Location

- Live location sharing
- Meetup coordination

### Notifications

- Push notifications (Firebase)
- Alerts for:
  - Friend requests


---

## Disclaimer

This project is developed for **demonstration and evaluation purposes**.
Backend services may be: Modified, Rate-limited and Disabled after evaluation.

flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
