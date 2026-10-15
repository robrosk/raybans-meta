// Objective-C++ bridge: Swift <-> rb::SessionEngine.
//
// The .mm file is bilingual on purpose. Everything above the @implementation
// is invisible to Swift; Swift only sees RBSessionBridge.h.
//
// Threading contract: the engine fires callbacks on adapter threads. Every
// callback is re-dispatched to the main queue here before touching blocks.

#import "RBSessionBridge.h"

#include <dispatch/dispatch.h>

#include <memory>
#include <vector>

#include "rb/session_engine.h"

// ---------------------------------------------------------------------------
// C++ adapters: rb::ICameraInput etc. -> Obj-C protocol objects (Swift side)
// ---------------------------------------------------------------------------

class ObjCCameraAdapter : public rb::ICameraInput {
public:
    explicit ObjCCameraAdapter(id<RBCameraInput> input) : input_(input) {}
    void setObserver(rb::ICameraObserver* o) override { observer_ = o; }
    void startStream() override { [input_ startStream]; }
    void stopStream() override { [input_ stopStream]; }
    void capturePhoto() override { [input_ capturePhoto]; }

    void deliverPhoto(NSData* jpeg, NSUInteger w, NSUInteger h) {
        if (!observer_) return;
        const uint8_t* bytes = static_cast<const uint8_t*>(jpeg.bytes);
        rb::Frame frame;
        frame.jpeg.assign(bytes, bytes + jpeg.length);
        frame.width = static_cast<uint32_t>(w);
        frame.height = static_cast<uint32_t>(h);
        frame.capturedAt = std::chrono::system_clock::now();
        observer_->onPhoto(std::move(frame));
    }
    void deliverStreamEvent(rb::StreamEvent e) {
        if (observer_) observer_->onStreamEvent(e);
    }

private:
    __weak id<RBCameraInput> input_;
    rb::ICameraObserver* observer_ = nullptr;
};

class ObjCMicrophoneAdapter : public rb::IMicrophoneInput {
public:
    explicit ObjCMicrophoneAdapter(id<RBMicrophoneInput> input) : input_(input) {}
    void setObserver(rb::IMicrophoneObserver* o) override { observer_ = o; }
    void startCapture() override { [input_ startCapture]; }
    void stopCapture() override { [input_ stopCapture]; }

    void deliverAudio(NSData* pcm16, NSUInteger rateHz) {
        if (!observer_) return;
        const int16_t* p = static_cast<const int16_t*>(pcm16.bytes);
        const size_t n = pcm16.length / sizeof(int16_t);
        rb::AudioChunk chunk;
        chunk.pcm16.assign(p, p + n);
        chunk.sampleRateHz = static_cast<uint32_t>(rateHz);
        observer_->onAudio(std::move(chunk));
    }
    void deliverLevel(float level) {
        if (observer_) observer_->onLevel(level);
    }

private:
    __weak id<RBMicrophoneInput> input_;
    rb::IMicrophoneObserver* observer_ = nullptr;
};

class ObjCDeviceStateAdapter : public rb::IDeviceStateProvider {
public:
    explicit ObjCDeviceStateAdapter(id<RBDeviceStateProvider> p) : provider_(p) {}
    void setObserver(rb::IDeviceStateObserver* o) override { observer_ = o; }
    void startMonitoring() override { [provider_ startMonitoring]; }
    void stopMonitoring() override { [provider_ stopMonitoring]; }

    void deliverState(int battery, bool hingeOpen, bool worn, bool thermal) {
        if (!observer_) return;
        rb::DeviceState s;
        s.batteryPercent = battery;
        s.hingeOpen = hingeOpen;
        s.worn = worn;
        s.thermalWarning = thermal;
        observer_->onDeviceState(s);
    }

private:
    __weak id<RBDeviceStateProvider> provider_;
    rb::IDeviceStateObserver* observer_ = nullptr;
};

// ---------------------------------------------------------------------------
// Engine observer: rb::IEngineObserver -> main queue -> Obj-C blocks
// ---------------------------------------------------------------------------

// One entry per addEngineObserver... call. Blocks live here (Obj-C, ARC).
@interface RBEngineObserverEntry : NSObject
@property(nonatomic, copy) void (^onState)(RBSessionState);
@property(nonatomic, copy) void (^onPhoto)(NSData*, NSDate*);
@property(nonatomic, copy) void (^onAudio)(NSData*, NSUInteger);
@property(nonatomic, copy) void (^onLevel)(float);
@property(nonatomic, copy) void (^onDevice)(NSInteger, BOOL, BOOL, BOOL);
@property(nonatomic, copy) void (^onError)(NSString*);
@end
@implementation RBEngineObserverEntry
@end

@interface RBSessionBridge ()
- (NSArray<RBEngineObserverEntry*>*)engineObserverEntries;
- (void)deliverPhoto:(NSData*)jpeg width:(NSUInteger)w height:(NSUInteger)h;
- (void)deliverStreamEvent:(RBStreamEvent)e;
- (void)deliverAudio:(NSData*)pcm16 sampleRateHz:(NSUInteger)rateHz;
- (void)deliverAudioLevel:(float)level;
- (void)deliverDeviceState:(NSInteger)battery
                 hingeOpen:(BOOL)hingeOpen
                      worn:(BOOL)worn
             thermalWarning:(BOOL)thermal;
@end

class EngineObserverForwarder : public rb::IEngineObserver {
public:
    explicit EngineObserverForwarder(RBSessionBridge* bridge) : bridge_(bridge) {}

    void onStateChanged(rb::SessionState s) override {
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onState) e.onState(static_cast<RBSessionState>(s));
        });
    }
    void onPhoto(rb::Frame frame) override {
        NSData* jpeg = [NSData dataWithBytes:frame.jpeg.data() length:frame.jpeg.size()];
        const double t =
            std::chrono::duration<double>(frame.capturedAt.time_since_epoch()).count();
        NSDate* at = [NSDate dateWithTimeIntervalSince1970:t];
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onPhoto) e.onPhoto(jpeg, at);
        });
    }
    void onAudio(rb::AudioChunk chunk) override {
        NSData* pcm = [NSData dataWithBytes:chunk.pcm16.data()
                                    length:chunk.pcm16.size() * sizeof(int16_t)];
        const NSUInteger rate = chunk.sampleRateHz;
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onAudio) e.onAudio(pcm, rate);
        });
    }
    void onAudioLevel(float level) override {
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onLevel) e.onLevel(level);
        });
    }
    void onDeviceState(rb::DeviceState s) override {
        const NSInteger battery = s.batteryPercent;
        const BOOL hinge = s.hingeOpen ? YES : NO;
        const BOOL worn = s.worn ? YES : NO;
        const BOOL thermal = s.thermalWarning ? YES : NO;
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onDevice) e.onDevice(battery, hinge, worn, thermal);
        });
    }
    void onError(std::string message) override {
        NSString* msg = [NSString stringWithUTF8String:message.c_str()];
        fanOut(^(RBEngineObserverEntry* e) {
            if (e.onError) e.onError(msg ?: @"unknown error");
        });
    }

private:
    __weak RBSessionBridge* bridge_;

    void fanOut(void (^perEntry)(RBEngineObserverEntry*)) {
        RBSessionBridge* bridge = bridge_;
        if (!bridge) return;
        NSArray<RBEngineObserverEntry*>* entries = [bridge engineObserverEntries];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (RBEngineObserverEntry* e in entries) perEntry(e);
        });
    }
};

// ---------------------------------------------------------------------------
// Sink handed to Swift adapters; forwards into the C++ adapters via the bridge
// ---------------------------------------------------------------------------

@interface RBInputSinkImpl : NSObject <RBInputSink>
- (instancetype)initWithBridge:(RBSessionBridge*)bridge;
@end

@implementation RBInputSinkImpl {
    __weak RBSessionBridge* _bridge;
}
- (instancetype)initWithBridge:(RBSessionBridge*)bridge {
    if (self = [super init]) _bridge = bridge;
    return self;
}
- (void)didCapturePhoto:(NSData*)jpeg width:(NSUInteger)w height:(NSUInteger)h {
    [_bridge deliverPhoto:jpeg width:w height:h];
}
- (void)didStreamEvent:(RBStreamEvent)e {
    [_bridge deliverStreamEvent:e];
}
- (void)didCaptureAudio:(NSData*)pcm16 sampleRateHz:(NSUInteger)rateHz {
    [_bridge deliverAudio:pcm16 sampleRateHz:rateHz];
}
- (void)didAudioLevel:(float)level {
    [_bridge deliverAudioLevel:level];
}
- (void)didUpdateDeviceState:(NSInteger)battery
                   hingeOpen:(BOOL)h
                        worn:(BOOL)w
               thermalWarning:(BOOL)t {
    [_bridge deliverDeviceState:battery hingeOpen:h worn:w thermalWarning:t];
}
@end

// ---------------------------------------------------------------------------
// RBSessionBridge
// ---------------------------------------------------------------------------

@implementation RBSessionBridge {
    std::unique_ptr<rb::SessionEngine> _engine;
    std::unique_ptr<EngineObserverForwarder> _forwarder;
    std::shared_ptr<ObjCCameraAdapter> _cameraAdapter;
    std::shared_ptr<ObjCMicrophoneAdapter> _micAdapter;
    std::shared_ptr<ObjCDeviceStateAdapter> _deviceAdapter;
    RBInputSinkImpl* _sink;
    NSMutableArray<RBEngineObserverEntry*>* _observerEntries;
}

- (instancetype)init {
    if (self = [super init]) {
        _engine = std::make_unique<rb::SessionEngine>();
        _forwarder = std::make_unique<EngineObserverForwarder>(self);
        _engine->setObserver(_forwarder.get());
        _observerEntries = [NSMutableArray array];
    }
    return self;
}

- (NSArray<RBEngineObserverEntry*>*)engineObserverEntries {
    return [_observerEntries copy];
}

- (void)ensureSink {
    if (!_sink) _sink = [[RBInputSinkImpl alloc] initWithBridge:self];
}

- (void)addEngineObserverWithState:(void (^)(RBSessionState))onState
                             photo:(void (^)(NSData*, NSDate*))onPhoto
                             audio:(void (^)(NSData*, NSUInteger))onAudio
                             level:(void (^)(float))onLevel
                       deviceState:(void (^)(NSInteger, BOOL, BOOL, BOOL))onDevice
                             error:(void (^)(NSString*))onError {
    RBEngineObserverEntry* entry = [RBEngineObserverEntry new];
    entry.onState = onState;
    entry.onPhoto = onPhoto;
    entry.onAudio = onAudio;
    entry.onLevel = onLevel;
    entry.onDevice = onDevice;
    entry.onError = onError;
    [_observerEntries addObject:entry];
}

- (void)attachCameraInput:(id<RBCameraInput>)input {
    _cameraAdapter = std::make_shared<ObjCCameraAdapter>(input);
    [self ensureSink];
    [input attachSink:_sink];
    _engine->attachCamera(_cameraAdapter);
}

- (void)attachMicrophoneInput:(id<RBMicrophoneInput>)input {
    _micAdapter = std::make_shared<ObjCMicrophoneAdapter>(input);
    [self ensureSink];
    [input attachSink:_sink];
    _engine->attachMicrophone(_micAdapter);
}

- (void)attachDeviceStateProvider:(id<RBDeviceStateProvider>)provider {
    _deviceAdapter = std::make_shared<ObjCDeviceStateAdapter>(provider);
    [self ensureSink];
    [provider attachSink:_sink];
    _engine->attachDeviceState(_deviceAdapter);
}

// Sink delivery (called on whatever thread the adapter used; the C++ side
// just records — fan-out to main happens in EngineObserverForwarder).
- (void)deliverPhoto:(NSData*)jpeg width:(NSUInteger)w height:(NSUInteger)h {
    if (_cameraAdapter) _cameraAdapter->deliverPhoto(jpeg, w, h);
}
- (void)deliverStreamEvent:(RBStreamEvent)e {
    if (_cameraAdapter) _cameraAdapter->deliverStreamEvent(static_cast<rb::StreamEvent>(e));
}
- (void)deliverAudio:(NSData*)pcm16 sampleRateHz:(NSUInteger)rateHz {
    if (_micAdapter) _micAdapter->deliverAudio(pcm16, rateHz);
}
- (void)deliverAudioLevel:(float)level {
    if (_micAdapter) _micAdapter->deliverLevel(level);
}
- (void)deliverDeviceState:(NSInteger)battery
                 hingeOpen:(BOOL)hingeOpen
                      worn:(BOOL)worn
             thermalWarning:(BOOL)thermal {
    if (_deviceAdapter)
        _deviceAdapter->deliverState((int)battery, hingeOpen == YES, worn == YES,
                                     thermal == YES);
}

// User intents
- (void)beginRegistration { _engine->beginRegistration(); }
- (void)registrationComplete { _engine->registrationComplete(); }
- (void)startSession { _engine->startSession(); }
- (void)pauseSession { _engine->pauseSession(); }
- (void)resumeSession { _engine->resumeSession(); }
- (void)stopSession { _engine->stopSession(); }
- (void)capturePhoto { _engine->capturePhoto(); }

// Glasses-initiated events
- (void)onHingeClosed { _engine->onHingeClosed(); }
- (void)onTakenOff { _engine->onTakenOff(); }

@end
