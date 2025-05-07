# Xcode Simulator Testing Guide

This guide provides basic instructions for testing the Open WebUI iOS app in Xcode Simulator.

## Basic Simulator Usage

### Launch Simulator
1. Open the Open WebUI iOS project in Xcode
2. Select a device from the device menu in toolbar (near the Run/Stop buttons)
3. Click the "Run" button (play icon) or press Cmd+R

### Switch Device Types
- While Simulator is running: File → Open Simulator → [Choose Device]
- Or quit current Simulator and select different device in Xcode toolbar

### Essential Controls
- Home button: Cmd+Shift+H
- Rotate device: Cmd+Left/Right Arrow
- Take screenshot: Cmd+S
- Toggle keyboard: Cmd+K
- Change device orientation: Hardware → Rotate Left/Right

## Testing Different Conditions

### Device Variations
- Test on various iPhone sizes (mini, standard, Pro Max)
- Test on iPad models in both orientations
- Try both light and dark mode (Features → Toggle Appearance)
- Test with different Dynamic Type sizes (Settings → Accessibility)

### Network and Performance
- Simulate slow network: Debug → Slow Animations
- Test location features: Features → Location → Custom Location

### Accessibility Testing
- Enable VoiceOver: Hardware → Accessibility → VoiceOver
- Navigate the app using only VoiceOver gestures
- Ensure all UI elements have appropriate accessibility labels

## UI/UX Testing Checklist

### Core Flows
- [ ] Complete onboarding process
- [ ] Connect to an Ollama server
- [ ] Configure API keys for cloud providers
- [ ] Create new conversations
- [ ] Send messages and view responses
- [ ] Switch between models
- [ ] Adjust model parameters
- [ ] Navigate between conversations
- [ ] Use folder/tag organization

### Edge Cases
- [ ] Network connection errors
- [ ] Interrupted message streaming
- [ ] Background app state transitions
- [ ] Memory warnings (simulate with Debug menu)
- [ ] Large conversations with many messages

### Device-Specific Features
- [ ] Test split view on iPad
- [ ] Test landscape mode on iPhone
- [ ] Test compact layout on smaller devices
- [ ] Check keyboard shortcuts on iPad with keyboard

### Performance
- [ ] Scrolling performance in long conversations
- [ ] Message streaming responsiveness
- [ ] Background processing behavior
- [ ] UI transitions and animations

## Recording Test Results

Consider recording screen captures during testing for documentation purposes. Use QuickTime Player with:
1. File → New Screen Recording
2. Select the Simulator window
3. Record your testing session

This will help document any issues found for future reference.