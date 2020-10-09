# freezer

![Icon](https://notabug.org/exttex/freezer/raw/master/android/app/src/main/res/mipmap-hdpi/ic_launcher.png)

Free, unlimited, without DRM music streaming app, which uses Deezer as backend.
This app is still in BETA, so it is missing features and contains bugs.  
If you want to report bug or request feature, please open an issue.  

## Downloads:
Downloads are currently distributed in Telegram channel: https://t.me/freezereleases  
**You might get Play Protect warning - just select install anyway or disable Play Protect**  - it is because the keys used for signing this app are new.  
**App not installed** error - try different version (arm32/64) or uninstall old version.  

## Compile from source

Install flutter SDK: https://flutter.dev/docs/get-started/install  
(Optional) Generate keys for release build: https://flutter.dev/docs/deployment/android  

Download source:
```
git clone https://notabug.org/exttex/freezer
git submodule init 
git submodule update
```

Compile:  
```
flutter pub get
flutter build apk
```  
NOTE: You have to use own keys, or build debug using `flutter build apk --debug`

## Telegram group
https://t.me/freezerandroid

## Credits
Tobs: Beta tester  
Bas Curtiz: Icon, Logo, Banner, Design suggestions  
Deemix: https://notabug.org/RemixDev/deemix  
Annexhack: Android Auto help and resources  

### Translators:
Homam Al-Rawi: Arabic  
Markus: German  
Andrea: Italian  
Diego Hiro: Portuguese  
Annexhack: Russian  
Chino Pacia: Filipino  
ArcherDelta & PetFix: Spanish  
Shazzaam: Croatian  
VIRGIN_KLM: Greek  
koreezzz: Korean    
Fwwwwwwwwwweze: French    
kobyrevah: Hebrew   

### just_audio, audio_service
This app depends on modified just_audio and audio_service plugins with Deezer support.  
Both plugins were originally written by ryanheise, all credits to him.    
Forked versions for Freezer:  
https://notabug.org/exttex/just_audio/  
https://notabug.org/exttex/audio_service/  


## Support me
BTC: `14hcr4PGbgqeXd3SoXY9QyJFNpyurgrL9y`  
ETH: `0xb4D1893195404E1F4b45e5BDA77F202Ac4012288`  


## Disclaimer
```
Freezer was not developed for piracy, but educational and private usage.
It may be illegal to use this in your country!
I am not responsible in any way for the usage of this app.
```