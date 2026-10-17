#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Mirrors rb::SessionState in core/include/rb/types.h — order must match.
typedef NS_ENUM(NSInteger, RBSessionState) {
    RBSessionStateIdle,
    RBSessionStateRegistering,
    RBSessionStateReady,
    RBSessionStateStreaming,
    RBSessionStatePaused,
    RBSessionStateStopped,
    RBSessionStateFailed,
};

/// Mirrors rb::StreamEvent — order must match.
typedef NS_ENUM(NSInteger, RBStreamEvent) {
    RBStreamEventStarted,
    RBStreamEventPaused,
    RBStreamEventResumed,
    RBStreamEventStopped,
    RBStreamEventInterrupted,
};

/// Sink: Swift adapters push async results back into the engine through this.
/// All methods may be called from any thread; the bridge marshals to main.
@protocol RBInputSink <NSObject>
- (void)didCapturePhoto:(NSData *)jpeg width:(NSUInteger)width height:(NSUInteger)height;
- (void)didStreamEvent:(RBStreamEvent)event;
- (void)didCaptureAudio:(NSData *)pcm16 sampleRateHz:(NSUInteger)rateHz;
- (void)didAudioLevel:(float)level;
- (void)didUpdateDeviceState:(NSInteger)batteryPercent
                   hingeOpen:(BOOL)hingeOpen
                        worn:(BOOL)worn
               thermalWarning:(BOOL)thermalWarning;
/// Unrecoverable adapter error -> engine.fail(). Use sparingly; most failures
/// should surface as stream/device events so the state machine can recover.
- (void)didFail:(NSString *)message;
@end

@protocol RBCameraInput <NSObject>
- (void)attachSink:(id<RBInputSink>)sink;
- (void)startStream;
- (void)stopStream;
- (void)capturePhoto;
@end

@protocol RBMicrophoneInput <NSObject>
- (void)attachSink:(id<RBInputSink>)sink;
- (void)startCapture;
- (void)stopCapture;
@end

@protocol RBDeviceStateProvider <NSObject>
- (void)attachSink:(id<RBInputSink>)sink;
- (void)startMonitoring;
- (void)stopMonitoring;
@end

/// Swift-visible facade over rb::SessionEngine.
/// Owns the engine; translates between Obj-C blocks/protocols and C++.
@interface RBSessionBridge : NSObject

/// Registers an engine observer. Multiple observers are supported; each
/// receives every event on the main queue.
- (void)addEngineObserverWithState:(void (^)(RBSessionState state))onState
                             photo:(void (^)(NSData *jpeg, NSDate *capturedAt))onPhoto
                             audio:(void (^)(NSData *pcm16, NSUInteger sampleRateHz))onAudio
                             level:(void (^)(float level))onLevel
                       deviceState:(void (^)(NSInteger batteryPercent, BOOL hingeOpen, BOOL worn, BOOL thermalWarning))onDeviceState
                             error:(void (^)(NSString *message))onError;

- (void)attachCameraInput:(id<RBCameraInput>)input;
- (void)attachMicrophoneInput:(id<RBMicrophoneInput>)input;
- (void)attachDeviceStateProvider:(id<RBDeviceStateProvider>)provider;

// User intents -> SessionEngine
- (void)beginRegistration;
- (void)registrationComplete;
- (void)startSession;
- (void)pauseSession;
- (void)resumeSession;
- (void)stopSession;
- (void)capturePhoto;

// Glasses-initiated events -> SessionEngine
- (void)onHingeClosed;
- (void)onTakenOff;

@end

NS_ASSUME_NONNULL_END
