# freezer

Free, unlimited, without DRM music streaming app, which uses Deezer as backend.
This app is still in BETA, so it is missing features and contains bugs.  
If you want to report bug or request feature, please open an issue.  

## Downloads:
Downloads are currently distributed in [Telegram channel](https://t.me/freezereleases) and the [Freezer website](https://www.freezer.life/)  
**You might get Play Protect warning - just select install anyway or disable Play Protect**  - it is because the keys used for signing this app are new.  
**App not installed** error - try different version (arm32/64) or uninstall old version.  

## Compile from source

Install flutter SDK: https://flutter.dev/docs/get-started/install  
(Optional) Generate keys for release build: https://flutter.dev/docs/deployment/android  

Download source:
```
git clone https://git.rip/freezer/freezer
git submodule init 
git submodule update
```

Compile:  
```
flutter pub get
flutter build apk
```  
NOTE: You have to use own keys, or build debug using `flutter build apk --debug`

## Links
Telegram group: https://t.me/freezerandroid  
Discord server: https://discord.gg/7ap654Tp3z  


## Credits
**Tobs**: Beta tester  
**Xandar**: Community manager, helper, tester  
**Bas Curtiz**: Icon, Logo, Banner, Design suggestions  
**Deemix**: https://git.rip/RemixDev/deemix/  
**Annexhack**: Android Auto help and resources  

**Huge thanks to all the Crowdin translators and all the contributors to this project <3**

### just_audio, audio_service
This app depends on modified just_audio and audio_service plugins with Deezer support.  
Both plugins were originally written by ryanheise, all credits to him.    
Forked versions for Freezer:  
https://git.rip/freezer/just_audio  
https://git.rip/freezer/audio_service

## Support me
BTC: `14hcr4PGbgqeXd3SoXY9QyJFNpyurgrL9y`  
ETH: `0xb4D1893195404E1F4b45e5BDA77F202Ac4012288`  


## Disclaimer
```
Freezer was not developed for piracy, but educational and private usage.
It may be illegal to use this in your country!
I am not responsible in any way for the usage of this app.
```
