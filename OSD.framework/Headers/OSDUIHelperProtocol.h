@class NSString;

@protocol OSDUIHelperProtocol
- (void)showFullScreenImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecToAnimate:(unsigned int)arg4;
- (void)fadeClassicImageOnDisplay:(unsigned int)arg1;
- (void)showImageAtPath:(NSString *)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(NSString *)arg5;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 filledChiclets:(unsigned int)arg5 totalChiclets:(unsigned int)arg6 locked:(BOOL)arg7;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(NSString *)arg5;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4;
@end

