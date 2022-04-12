# Current development
- CSGO: emote
- CSS: done (if you want more module contact me)
- L4D2: now supported ([youtube](https://www.youtube.com/watch?v=70m5xKlp1Wo))
- TF2: now supported

# Newly added
- Update (10/9/2021), the store is rewritten for new enum struct syntax and can compile in SM 1.11 without any errors/warning.
[image](https://user-images.githubusercontent.com/58926275/136654734-1741fedc-c541-4e5a-bc4f-ad0283750240.png)

# zephyrus-store (support SM 1.10 and SM 1.11).
WARNING: THERE ARE MANY WARNING ABOUT RETURN VALUE IN NEWEST 1.11 COMPILER AND YOU CAN IGNORE THOSE.
My rewritten zephyrus store

Store system is mainly support for CS:GO.

P/S: Note. Store mainly supported for csgo, any others game (css, l4d2) may have some module that need to rework to be able to use. I will rework any that needed and will store in `<game_name>_modules` folders. Check for it (if you see no item that store in that folder, which mean you need to install any you wish from the main scripting folder and test run if you may find any error.)

# Modules that has preview support:
- Player Skin (by zephyrus) [youtube](https://www.youtube.com/watch?v=pzkwoiB-jlo)
- Custom weapon Model Skin  (by bbs.93x.net) [youtube](https://www.youtube.com/watch?v=TT7CwhIIPEc)
- Life live pet (with idle2 animation config - Rare idle animation => Support for spawn and death animation soon) by Totenfluch [youtube](https://www.youtube.com/watch?v=Fn-_MbWzL_Q)
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
	(Please uncomment //#define WEAPONS_KNIVES at line #202 to enable this module)
- Name tag, name and message color.
- more will be supported
# Modules has no preview support:
- PaintBall Effects (by shanapu)
- Bullet Spark (by shanapu)
- Grenade trail (by zephyrus)
- Laser sight (by zephyrus)
- Colored Smoke ported from SHOP. ([youtube](https://www.youtube.com/watch?v=cTyMnAmgixI))
	(You can change smoke color or change smoke particle's material to custom material. Current no preview support. Preview will support in 1.1 version)
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

# Important links
Contact me via steam for bug report:
https://steamcommunity.com/id/nuclearsilo/

# Special Thank
Original store by Zephyrus, Preview system by Kxnrl, Some code from Shanapu's MyStore (gamble)

# Credits/Spezial Thanks:
sourcemod team, Zephyrus (dvarnai), Hexer10, bara, Kxnrl, Totenfluch, dordnung, Franc1sco, Drixevel, CZE|EMINEM, Kuristaja, maoling, In*Victus, rogeraabbccdd, Mitchell, gubka, FrozDark, SWAT_88, Bacardi, PeEzZ, Rachnus
