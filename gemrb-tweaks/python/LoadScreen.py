import GemRB

# 2 mandatory functions called by core
def SetLoadScreen ():
    return

# set up the progressbar, so core can notify us when loading finishes
def StartLoadScreen ():
	LoadScreen = GemRB.LoadWindow (0, "guils")
	LoadScreen.AddAlias ("LOADWIN") # an alternative to a global var
	LoadScreen.SetVisible (False) # hide the whole window

	Bar = LoadScreen.GetControl (0)
	Bar.AddAlias ("LOAD_PROG")
	Bar.SetVarAssoc ("Progress", 0)
	Bar.OnEndReached (EndLoadScreen)
	return

def EndLoadScreen ():
	GemRB.GetView ("LOADWIN").Close ()
	GemRB.GamePause (0, 0) # unpause
	return
