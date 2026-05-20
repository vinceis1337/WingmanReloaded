; Ultimatum Modifier Manager GUI

UltimatumRowNumber := 0

; ─────────────────────────────────────────────────────────────────────────────
; Load JSON from path into WR.UltimatumMods.Modifiers (silent on missing file)
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadFromPath(path)
{
  global WR
  If (!FileExist(path))
    Return
  Try {
    obj := JSON.Load(FileOpen(path, "r").Read())
  } Catch {
    Return
  }
  WR.UltimatumMods.Modifiers := obj
}

; ─────────────────────────────────────────────────────────────────────────────
; Open / Rebuild the Ultimatum Modifier Manager window
; ─────────────────────────────────────────────────────────────────────────────
UltimatumModsUI:
  Gui, UltimatumUI: New
  Gui, UltimatumUI: Default
  Gui, UltimatumUI: +AlwaysOnTop -MinimizeBox
  Gui, UltimatumUI: Add, ListView, w950 h400 -wrap -Multi Grid gUltimatumListViewClick vUltimatumListView
    , Modifier Name|Tier|Detail|Rating|FindText
  UltimatumRefreshList()
  Loop % LV_GetCount("Column")
    LV_ModifyCol(A_Index, "AutoHdr")

  ; Row 1 – persistence buttons + loaded-file indicator
  Gui, UltimatumUI: Add, Button, gSaveUltimatumJson w160 h30,      Save Modifier Json
  Gui, UltimatumUI: Add, Button, gLoadUltimatumJson w160 h30 x+5,  Load Modifier Json
  SplitPath, UltimatumModsJsonPath, UT_ShortName
  Gui, UltimatumUI: Add, Text, vUltimatumLoadedFile x+10 yp+8, %UT_ShortName%

  ; Row 2 – Debug tools GroupBox
  Gui, UltimatumUI: Add, GroupBox, Section w600 h55 xs y+10, Debug
  Gui, UltimatumUI: Add, Button, gAddUltimatumRow       w115 h28 xs+5 ys+18, Add Modifier
  Gui, UltimatumUI: Add, Button, gMoveUltimatumUp       w100 h28 x+5,        Move Up
  Gui, UltimatumUI: Add, Button, gMoveUltimatumDown     w100 h28 x+5,        Move Down
  Gui, UltimatumUI: Add, Button, gDuplicateUltimatumRow w120 h28 x+5,        Duplicate Row

  Gui, UltimatumUI: Show, , Ultimatum Modifier Manager
Return

; ─────────────────────────────────────────────────────────────────────────────
; ListView event – double-click opens the row editor
; ─────────────────────────────────────────────────────────────────────────────
UltimatumListViewClick:
  If (A_GuiEvent = "DoubleClick")
  {
    UltimatumRowNumber := A_EventInfo
    If (UltimatumRowNumber = 0)
      Return
    LV_GetText(UT_Name,     UltimatumRowNumber, 1)
    LV_GetText(UT_Tier,     UltimatumRowNumber, 2)
    LV_GetText(UT_Detail,   UltimatumRowNumber, 3)
    LV_GetText(UT_Rating,   UltimatumRowNumber, 4)
    LV_GetText(UT_FindText, UltimatumRowNumber, 5)

    Gui, UltimatumEditUI: New
    Gui, UltimatumEditUI: +AlwaysOnTop -MinimizeBox
    Gui, UltimatumEditUI: Add, Text,         Section,                Modifier Name:
    Gui, UltimatumEditUI: Add, Edit,         vUT_Edit_Name w240 xs y+3,       %UT_Name%
    Gui, UltimatumEditUI: Add, Text,         xs y+8,                 Tier:
    Gui, UltimatumEditUI: Add, Edit,         vUT_Edit_Tier w80 xs y+3,        %UT_Tier%
    Gui, UltimatumEditUI: Add, Text,         xs y+8,                 Detail:
    Gui, UltimatumEditUI: Add, Edit,         vUT_Edit_Detail w380 xs y+3,     %UT_Detail%
    Gui, UltimatumEditUI: Add, Text,         xs y+8,                 Rating:
    Gui, UltimatumEditUI: Add, DropDownList, vUT_Edit_Rating xs y+3,          Easy|Manageable|Hard|Deadly
    GuiControl, UltimatumEditUI: ChooseString, UT_Edit_Rating, %UT_Rating%
    Gui, UltimatumEditUI: Add, Text,         xs y+8,                 FindText:
    Gui, UltimatumEditUI: Add, Edit,         vUT_Edit_FindText w380 xs y+3 r3, %UT_FindText%
    Gui, UltimatumEditUI: Add, Button,       gSaveUltimatumRow  w120 h28 xs y+10, Save
    Gui, UltimatumEditUI: Add, Button,       gDeleteUltimatumRow w120 h28 x+5,    Delete Row
    Gui, UltimatumEditUI: Show, , Edit Ultimatum Modifier
  }
Return

; ─────────────────────────────────────────────────────────────────────────────
; Save edits back into the ListView row
; ─────────────────────────────────────────────────────────────────────────────
SaveUltimatumRow:
  Gui, UltimatumEditUI: Submit, NoHide
  Gui, UltimatumUI: Default
  LV_Modify(UltimatumRowNumber,, UT_Edit_Name, UT_Edit_Tier, UT_Edit_Detail, UT_Edit_Rating, UT_Edit_FindText)
  Gui, UltimatumEditUI: Hide
Return

; ─────────────────────────────────────────────────────────────────────────────
; Delete the currently-edited row
; ─────────────────────────────────────────────────────────────────────────────
DeleteUltimatumRow:
  Gui, UltimatumEditUI: Hide
  Gui, UltimatumUI: Default
  LV_Delete(UltimatumRowNumber)
Return

; ─────────────────────────────────────────────────────────────────────────────
; Add a blank placeholder row at the bottom
; ─────────────────────────────────────────────────────────────────────────────
AddUltimatumRow:
  Gui, UltimatumUI: Default
  LV_Add("", "New Modifier", "1", "", "Easy", "")
  Loop % LV_GetCount("Column")
    LV_ModifyCol(A_Index, "AutoHdr")
Return

; ─────────────────────────────────────────────────────────────────────────────
; Move selected row one position up
; ─────────────────────────────────────────────────────────────────────────────
MoveUltimatumUp:
  Gui, UltimatumUI: Default
  selRow := LV_GetNext(0, "F")
  If (selRow <= 1)
    Return
  LV_GetText(UT_Name,     selRow, 1)
  LV_GetText(UT_Tier,     selRow, 2)
  LV_GetText(UT_Detail,   selRow, 3)
  LV_GetText(UT_Rating,   selRow, 4)
  LV_GetText(UT_FindText, selRow, 5)
  LV_Delete(selRow)
  LV_Insert(selRow - 1, "", UT_Name, UT_Tier, UT_Detail, UT_Rating, UT_FindText)
  LV_Modify(selRow - 1, "Focus Select")
Return

; ─────────────────────────────────────────────────────────────────────────────
; Move selected row one position down
; ─────────────────────────────────────────────────────────────────────────────
MoveUltimatumDown:
  Gui, UltimatumUI: Default
  selRow := LV_GetNext(0, "F")
  If (selRow = 0 || selRow >= LV_GetCount())
    Return
  LV_GetText(UT_Name,     selRow, 1)
  LV_GetText(UT_Tier,     selRow, 2)
  LV_GetText(UT_Detail,   selRow, 3)
  LV_GetText(UT_Rating,   selRow, 4)
  LV_GetText(UT_FindText, selRow, 5)
  LV_Delete(selRow)
  LV_Insert(selRow + 1, "", UT_Name, UT_Tier, UT_Detail, UT_Rating, UT_FindText)
  LV_Modify(selRow + 1, "Focus Select")
Return

; ─────────────────────────────────────────────────────────────────────────────
; Duplicate selected row and insert the copy immediately below it
; ─────────────────────────────────────────────────────────────────────────────
DuplicateUltimatumRow:
  Gui, UltimatumUI: Default
  selRow := LV_GetNext(0, "F")
  If (selRow = 0)
    Return
  LV_GetText(UT_Name,     selRow, 1)
  LV_GetText(UT_Tier,     selRow, 2)
  LV_GetText(UT_Detail,   selRow, 3)
  LV_GetText(UT_Rating,   selRow, 4)
  LV_GetText(UT_FindText, selRow, 5)
  LV_Insert(selRow + 1, "", UT_Name, UT_Tier, UT_Detail, UT_Rating, UT_FindText)
  LV_Modify(selRow + 1, "Focus Select")
Return

; ─────────────────────────────────────────────────────────────────────────────
; Persist the current ListView rows to a JSON file chosen by the user
; ─────────────────────────────────────────────────────────────────────────────
SaveUltimatumJson:
  Gui, UltimatumUI: Default
  WR.UltimatumMods.Modifiers := []
  rowCount := LV_GetCount()
  Loop % rowCount
  {
    LV_GetText(UT_Name,     A_Index, 1)
    LV_GetText(UT_Tier,     A_Index, 2)
    LV_GetText(UT_Detail,   A_Index, 3)
    LV_GetText(UT_Rating,   A_Index, 4)
    LV_GetText(UT_FindText, A_Index, 5)
    aux := {"ModifierName": UT_Name, "Tier": UT_Tier, "Detail": UT_Detail
          , "Rating": UT_Rating, "FindText": UT_FindText}
    WR.UltimatumMods.Modifiers.Push(aux)
  }
  FileSelectFile, UT_SavePath, S16, %UltimatumModsJsonPath%
    , Save Modifier Json, JSON Files (*.json)
  If (UT_SavePath = "")
    Return
  FileDelete, %UT_SavePath%
  FileAppend, % JSON.Dump(WR.UltimatumMods.Modifiers,, 2), %UT_SavePath%
  UltimatumModsJsonPath := UT_SavePath
  IniWrite, %UltimatumModsJsonPath%, %A_ScriptDir%\save\Settings.ini, Automation, UltimatumModsJsonPath
  SplitPath, UltimatumModsJsonPath, UT_ShortName
  GuiControl,, UltimatumLoadedFile, %UT_ShortName%
Return

; ─────────────────────────────────────────────────────────────────────────────
; Load modifier rows from a user-selected JSON file
; ─────────────────────────────────────────────────────────────────────────────
LoadUltimatumJson:
  FileSelectFile, UT_LoadPath, 3, %UltimatumModsJsonPath%
    , Load Modifier Json, JSON Files (*.json)
  If (UT_LoadPath = "")
    Return
  Try {
    obj := JSON.Load(FileOpen(UT_LoadPath, "r").Read())
  } Catch e {
    MsgBox, 262144, Error loading Ultimatum mods, % e
    Return
  }
  WR.UltimatumMods.Modifiers := obj
  UltimatumModsJsonPath := UT_LoadPath
  IniWrite, %UltimatumModsJsonPath%, %A_ScriptDir%\save\Settings.ini, Automation, UltimatumModsJsonPath
  Gui, UltimatumUI: Default
  LV_Delete()
  UltimatumRefreshList()
  Loop % LV_GetCount("Column")
    LV_ModifyCol(A_Index, "AutoHdr")
  SplitPath, UltimatumModsJsonPath, UT_ShortName
  GuiControl,, UltimatumLoadedFile, %UT_ShortName%
Return

; ─────────────────────────────────────────────────────────────────────────────
; Populate ListView from WR.UltimatumMods.Modifiers (call with UltimatumUI as default)
; ─────────────────────────────────────────────────────────────────────────────
UltimatumRefreshList()
{
  For k, v in WR.UltimatumMods.Modifiers
    LV_Add("", v["ModifierName"], v["Tier"], v["Detail"], v["Rating"], v["FindText"])
}
