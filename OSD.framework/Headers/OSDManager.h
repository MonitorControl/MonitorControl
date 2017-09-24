#import "OSDUIHelperProtocol.h"

@class NSXPCConnection;

@interface OSDManager : NSObject <OSDUIHelperProtocol>
{
    id <OSDUIHelperProtocol> _proxyObject;
    NSXPCConnection *connection;
}

+ (id)sharedManager;
@property(retain) NSXPCConnection *connection; // @synthesize connection;
- (void)showFullScreenImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecToAnimate:(unsigned int)arg4;
- (void)fadeClassicImageOnDisplay:(unsigned int)arg1;
- (void)showImageAtPath:(id)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(id)arg5;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 filledChiclets:(unsigned int)arg5 totalChiclets:(unsigned int)arg6 locked:(BOOL)arg7;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(id)arg5;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4;
@property(readonly) id <OSDUIHelperProtocol> remoteObjectProxy; // @dynamic remoteObjectProxy;

@end
