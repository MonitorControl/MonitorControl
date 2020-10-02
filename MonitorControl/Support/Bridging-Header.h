#pragma once

#import <Foundation/Foundation.h>
#import <OSD/OSDManager.h>

#import <CoreGraphics/CoreGraphics.h>

double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetDynamicLinearBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetLinearBrightness(CGDirectDisplayID display);
void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetDynamicLinearBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetLinearBrightness(CGDirectDisplayID display, double brightness);

CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);
