# Current development
- CSGO: emote
- CSS: done (if you want more module contact me)
- L4D2: now supported ([youtube](https://www.youtube.com/watch?v=70m5xKlp1Wo))
- TF2: now supported

# Newly added
- Update syntax to stable SM 1.11 (since SM 1.11 is now the stable branch for sourcemod. Any error that cause with SM 1.10 will be no longer supported).

# zephyrus-store (compatible with SM 1.11).
My rewritten zephyrus store

Store system is mainly support for CS:GO.

P/S: Note. Store mainly supported for csgo, any others game (css, l4d2) may have some module that need to rework to be able to use. I will rework any that needed and will store in `<game_name>_modules` folders. Check for it (if you see no item that store in that folder, which mean you need to install any you wish from the main scripting folder and test run if you may find any error.)

# Modules that has preview support:
- Player Skin (by zephyrus) [youtube](https://www.youtube.com/watch?v=pzkwoiB-jlo)
  
  P/S: You may get script executed timeout if you add too many model and the precache sometime get bugged and cause server to crash. Please use [these](https://forums.alliedmods.net/showthread.php?p=602270) [plugin](https://forums.alliedmods.net/showthread.php?t=269792) to precache and add all the required file to the download table.
- Custom weapon Model Skin  (by bbs.93x.net) [youtube](https://www.youtube.com/watch?v=TT7CwhIIPEc)
- Life live pet (with idle, idle2, spawn, death animation support) by Totenfluch [youtube](https://www.youtube.com/watch?v=Fn-_MbWzL_Q)
- Custom MVP music (by kento and shanapu)
- Zombie reloaded playerclasses (original by zephyrus) [youtube](https://www.youtube.com/watch?v=NUZu5MEvvXk)
- Hats preview (original by zephyrus)
- Trails preview (original by zephyrus)
- Aura particle preview (by shanapu)
- Kill Effects particle preview (by shanapu)
- Spawn Effects particle preview (by shanapu)
- Grenade skin (by zephyrus)
- Sprays
- Say sound
- Re-add valve's weapon skins and knives (warning: this may cause your server get ban. Please use at your own risk).
	(Please uncomment //#define WEAPONS_KNIVES to enable this module)
- Name tag, scoreboard tag, name and message color.
- Colored Smoke ported from SHOP. ([youtube](https://www.youtube.com/watch?v=cTyMnAmgixI))
	(You can change smoke color or change smoke particle's material to custom material.)
- more will be supported
# Modules has no preview support:
- PaintBall Effects (by shanapu)
- Bullet Spark (by shanapu)
- Grenade trail (by zephyrus)
- Laser sight (by zephyrus)
# New feature added:
- Added "preview" key value enable preview system
- Added "steam" key value which support for exclusive skin (special thanks Shanabu)
- Case opening system (lootbox) [youtube](https://www.youtube.com/watch?v=akGObAWnRqk)
- "description" key value
- Store's search for item function ([youtube](https://www.youtube.com/watch?v=xZyDtC6PDQM))
- Store Logging for module (To find out errors. Both SQL and SQLite are supported)
![log](https://user-images.githubusercontent.com/58926275/125444645-8c83105f-cc83-411d-bab9-a9e5689af9d9.png)
- Store Voucher system module generating code, redeem, check, and buy. Both SQL and SQLite are supported)
![voucher](https://user-images.githubusercontent.com/58926275/125775715-a282139a-7b71-4b76-9dc6-b3c686459a07.png)
- Store Give away (v1.0)
- Store Math credits
- Store Top list
- Support for in-game reload items.txt config without having restart server. (You need to change or reload map or may get some bugs). Note this option only work for testing stuff. You still need a full restart on some items.
- Store Earning credits (Warning: This modules only supported for csgo. If you're using the 2009 source engine. Dont use this. If you're using csgo please disable all the earning method of the core store.sp in the cfg file)
- Added custom name tag color for client who bought the name tag.

# Private Modules
- Custom Weapon Model with shooting sound support (Contact me for more info). ([Preview video](https://youtu.be/iixbG1SIuJA)).

### How to install
* Download latest release or (green) Code button -> Download Zip.
* Extract all files on disk.
* Upload to server following folders (replace all the files): 
  * addons
  * cfg (You don't need to replace these .cfg but they list new cvar for the store.)
  * models ( optional )
  * materials ( optional )
  * particles ( optional )
  * sound ( optional )
* Go to your addons/sourcemod/scripting/ folder.
* Compile drag and drop store.sp to compile.exe
* Find store.smx inside compiled folder which created in the same directory.
* Drag store.smx to addons/sourcemod/plugins or addons/sourcemod/plugins/(your_new_sub_folder_for_store) (optional)
* Do the same way with module store_item_, store_gamble_, store_misc_ (Some module cannot work for some game please head to the <game_name>_modules in the same directory)
* Drag the compiled .smx module to the plugins/ folder
* Edit addons/sourcemod/configs/store/items.txt for your store items/menu.
* Run the server and check for error logs.


# Important links
- Contact me via steam for bug report:
https://steamcommunity.com/id/nuclearsilo/

- Resource for download:
https://drive.google.com/drive/folders/1Eol0XG_H2Ofuyx3K-TFJ-6j8DUKz0Df8?usp=sharing



# Special Thank
Original store by Zephyrus, Preview system by Kxnrl, Some code from Shanapu's MyStore (gamble)

# Credits/Spezial Thanks:
sourcemod team, Zephyrus (dvarnai), Hexer10, bara, Kxnrl, Totenfluch, dordnung, Franc1sco, Drixevel, CZE|EMINEM, Kuristaja, maoling, In*Victus, rogeraabbccdd, Mitchell, gubka, FrozDark, SWAT_88, Bacardi, PeEzZ, Rachnus
