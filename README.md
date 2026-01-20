# YouLoop
Adds a player button to enable/disable looping on the current video.

Repeat icons created by Uniconlabs - Flaticon.

## Building
- Clone [Theos](https://github.com/theos/theos) along with its submodules.
- Clone and Copy [iOS 18.6 SDK](https://github.com/Tonwalter888/iOS-18.6-SDK) to ``$THEOS/sdks``.
- CLone [YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader) into ``$THEOS/include``.
- Cd into your theos folder and cd back ``cd ..``,then clone [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) there.
- Clone YouLoop,cd into it and run ``make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless``. (You can remove the ``THEOS_PACKAGE_SCHEME=rootless`` part if you are using in jailbroken iOS.)