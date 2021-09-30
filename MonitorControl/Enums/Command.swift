//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

enum Command: UInt8 {
  case none = 0

  // Display Control
  case horizontalFrequency = 0xAC
  case verticalFrequency = 0xAE
  case sourceColorCoding = 0xB5
  case displayUsageTime = 0xC0
  case displayControllerId = 0xC8
  case displayFirmwareLevel = 0xC9
  case osdLanguage = 0xCC
  case powerMode = 0xD6
  case imageMode = 0xDB
  case vcpVersion = 0xDF

  // Geometry
  case horizontalPosition = 0x20
  case horizontalSize = 0x22
  case horizontalPincushion = 0x24
  case horizontalPincushionBalance = 0x26
  case horizontalConvergenceRB = 0x28
  case horizontalConvergenceMG = 0x29
  case horizontalLinearity = 0x2A
  case horizontalLinearityBalance = 0x2C
  case verticalPosition = 0x30
  case verticalSize = 0x32
  case verticalPincushion = 0x34
  case verticalPincushionBalance = 0x36
  case verticalConvergenceRB = 0x38
  case verticalConvergenceMG = 0x39
  case verticalLinearity = 0x3A
  case verticalLinearityBalance = 0x3C
  case horizontalParallelogram = 0x40
  case verticalParallelogram = 0x41
  case horizontalKeystone = 0x42
  case verticalKeystone = 0x43
  case rotation = 0x44
  case topCornerFlare = 0x46
  case topCornerHook = 0x48
  case bottomCornerFlare = 0x4A
  case bottomCornerHook = 0x4C
  case horizontalMirror = 0x82
  case verticalMirror = 0x84
  case displayScaling = 0x86
  case windowPositionTopLeftX = 0x95
  case windowPositionTopLeftY = 0x96
  case windowPositionBottomRightX = 0x97
  case windowPositionBottomRightY = 0x98
  case scanMode = 0xDA

  // Miscellaneous
  case degauss = 0x01
  case newControlValue = 0x02
  case softControls = 0x03
  case activeControl = 0x52
  case performancePreservation = 0x54
  case inputSelect = 0x60
  case ambientLightSensor = 0x66
  case remoteProcedureCall = 0x76
  case displayIdentificationOnDataOperation = 0x78
  case tvChannelUpDown = 0x8B
  case flatPanelSubPixelLayout = 0xB2
  case displayTechnologyType = 0xB6
  case displayDescriptorLength = 0xC2
  case transmitDisplayDescriptor = 0xC3
  case enableDisplayOfDisplayDescriptor = 0xC4
  case applicationEnableKey = 0xC6
  case displayEnableKey = 0xC7
  case statusIndicator = 0xCD
  case auxiliaryDisplaySize = 0xCE
  case auxiliaryDisplayData = 0xCF
  case outputSelect = 0xD0
  case assetTag = 0xD2
  case auxiliaryPowerOutput = 0xD7
  case scratchPad = 0xDE

  // Audio
  case audioSpeakerVolume = 0x62
  case speakerSelect = 0x63
  case audioMicrophoneVolume = 0x64
  case audioJackConnectionStatus = 0x65
  case audioMuteScreenBlank = 0x8D
  case audioTreble = 0x8F
  case audioBass = 0x91
  case audioBalanceLR = 0x93
  case audioProcessorMode = 0x94

  // OSD/Button Event Control
  case osd = 0xCA

  // Image Adjustment
  case sixAxisHueControlBlue = 0x9F
  case sixAxisHueControlCyan = 0x9E
  case sixAxisHueControlGreen = 0x9D
  case sixAxisHueControlMagenta = 0xA0
  case sixAxisHueControlRed = 0x9B
  case sixAxisHueControlYellow = 0x9C
  case sixAxisSaturationControlBlue = 0x5D
  case sixAxisSaturationControlCyan = 0x5C
  case sixAxisSaturationControlGreen = 0x5B
  case sixAxisSaturationControlMagenta = 0x5E
  case sixAxisSaturationControlRed = 0x59
  case sixAxisSaturationControlYellow = 0x5A
  case adjustZoom = 0x7C
  case autoColorSetup = 0x1F
  case autoSetup = 0x1E
  case autoSetupOnOff = 0xA2
  case backlightControlLegacy = 0x13
  case backlightLevelWhite = 0x6B
  case backlightLevelRed = 0x6D
  case backlightLevelGreen = 0x6F
  case backlightLevelBlue = 0x71
  case blockLutOperation = 0x75
  case clock = 0x0E
  case clockPhase = 0x3E
  case colorSaturation = 0x8A
  case colorTemperatureIncrement = 0x0B
  case colorTemperatureRequest = 0x0C
  case contrast = 0x12
  case displayApplication = 0xDC
  case fleshToneEnhancement = 0x11
  case focus = 0x1C
  case gamma = 0x72
  case grayScaleExpansion = 0x2E
  case horizontalMoire = 0x56
  case hue = 0x90
  case luminance = 0x10
  case lutSize = 0x73
  case screenOrientation = 0xAA
  case selectColorPreset = 0x14
  case sharpness = 0x87
  case singlePointLutOperation = 0x74
  case stereoVideoMode = 0xD4
  case tvBlackLevel = 0x92
  case tvContrast = 0x8E
  case tvSharpness = 0x8C
  case userColorVisionCompensation = 0x17
  case velocityScanModulation = 0x88
  case verticalMoire = 0x58
  case videoBlackLevelBlue = 0x70
  case videoBlackLevelGreen = 0x6E
  case videoBlackLevelRed = 0x6C
  case videoGainBlue = 0x1A
  case videoGainGreen = 0x18
  case videoGainRed = 0x16
  case windowBackground = 0x9A
  case windowControlOnOff = 0xA4
  case windowSelect = 0xA5
  case windowSize = 0xA6
  case windowTransparency = 0xA7

  // Preset Operations
  case restoreFactoryDefaults = 0x04
  case restoreFactoryLuminanceContrastDefaults = 0x05
  case restoreFactoryGeometryDefaults = 0x06
  case restoreFactoryColorDefaults = 0x08
  case restoreFactoryTvDefaults = 0x0A
  case settings = 0xB0

  // Manufacturer Specific
  case blackStabilizer = 0xF9 // LG 38UC99-W
  case colorPresetC = 0xE0
  case powerControl = 0xE1
  case topLeftScreenPurity = 0xE8
  case topRightScreenPurity = 0xE9
  case bottomLeftScreenPurity = 0xEA
  case bottomRightScreenPurity = 0xEB

  public static let brightness = luminance
}
