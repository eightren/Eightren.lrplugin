--[[----------------------------------------------------------------------------

 EEEEE  III  GGGG  H   H TTTTT RRRR   EEEEE  N   N
 E        I  G      H   H   T   R   R  E       NN  N
 EEEE     I  G  GG  HHHHH   T   RRRR   EEEE    N N N
 E        I  G   G  H   H   T   R  R   E       N  NN
 EEEEE  III  GGGG   H   H   T   R   R  EEEEE   N   N

 Plugin Created by Eightren
 https://eightren.com

NOTICE: Eightren permits you to use, modify, and distribute this file.

--------------------------------------------------------------------------------

Takes a folder as a parameter. This plugin will match all photos found in that
folder with the photos inside lightroom and will flag it using the selected
color.

------------------------------------------------------------------------------]]


return {
	
	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.eightren.EightrenTools',

	LrPluginName = "Eightren's Tools",

	-- Add the menu item to the Library menu.
	
	LrLibraryMenuItems = {
	    {
		    title = "Mark Photos using files",
		    file = "ColorMarker.lua",
		},
	},
	VERSION = { major=14, minor=1, revision=0, build="202412062302-d2b56666", },

}


	
