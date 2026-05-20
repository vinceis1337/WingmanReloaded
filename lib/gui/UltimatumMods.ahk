; Ultimatum Modifier Manager GUI

UltimatumLoadFromPath(path) {
    global WR
    if !FileExist(path)
        return
    try
        obj := JSON.Load(FileOpen(path, "r").Read())
    catch
        return
    WR.UltimatumMods.Modifiers := obj
}

; ─────────────────────────────────────────────────────────────────────────────
; Open / Rebuild the Ultimatum Modifier Manager window
; ─────────────────────────────────────────────────────────────────────────────
UltimatumModsUI(*) {
    global UltimatumUI, UltimatumLV, UltimatumFileLbl
    global WR, UltimatumModsJsonPath
    global YesUltimatumShowHighlight, YesUltimatumShowScreenshot

    UltimatumUI := Gui()
    UltimatumUI.Opt("+AlwaysOnTop -MinimizeBox")
    UltimatumUI.Title := "Ultimatum Modifier Manager"

    UltimatumLV := UltimatumUI.Add("ListView", "w950 h400 -wrap -Multi Grid",
        ["Modifier Name", "Tier", "Detail", "Rating", "FindText"])
    UltimatumLV.OnEvent("DoubleClick", UltimatumLVEdit)
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")

    ; Row 1 – persistence buttons + loaded-file label
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumUI.Add("Button", "w160 h30",     "Save Modifier Json").OnEvent("Click", UltimatumSaveJson)
    UltimatumUI.Add("Button", "w160 h30 x+5", "Load Modifier Json").OnEvent("Click", UltimatumLoadJson)
    UltimatumUI.Add("Button", "w120 h30 x+5", "Load Defaults").OnEvent("Click",      UltimatumLoadDefaults)
    UltimatumFileLbl := UltimatumUI.Add("Text", "x+10 yp+8", shortName)

    ; Row 2 – Debug group
    UltimatumUI.Add("GroupBox", "Section w700 h90 xs y+10", "Debug")
    UltimatumUI.Add("Button", "xs+5 ys+18 w115 h28", "Add Modifier").OnEvent("Click",    UltimatumAddRow)
    UltimatumUI.Add("Button", "x+5 w100 h28",         "Move Up").OnEvent("Click",        UltimatumMoveUp)
    UltimatumUI.Add("Button", "x+5 w100 h28",         "Move Down").OnEvent("Click",      UltimatumMoveDown)
    UltimatumUI.Add("Button", "x+5 w120 h28",         "Duplicate Row").OnEvent("Click",  UltimatumDuplicateRow)
    UltimatumUI.Add("Button", "x+5 w130 h28",         "Test Detection").OnEvent("Click", UltimatumTestDetection)
    cbHL := UltimatumUI.Add("CheckBox", "x+8 yp+6", "Show Highlight")
    cbHL.Value := YesUltimatumShowHighlight
    cbHL.OnEvent("Click", (*) => UltimatumSaveHighlight(cbHL))
    cbSS := UltimatumUI.Add("CheckBox", "x+8 yp", "Show Screenshot")
    cbSS.Value := YesUltimatumShowScreenshot
    cbSS.OnEvent("Click", (*) => UltimatumSaveScreenshot(cbSS))

    UltimatumUI.Show()
}

; ─────────────────────────────────────────────────────────────────────────────
; Populate ListView from WR.UltimatumMods.Modifiers
; ─────────────────────────────────────────────────────────────────────────────
UltimatumRefreshList() {
    global UltimatumLV, WR
    for k, v in WR.UltimatumMods.Modifiers
        UltimatumLV.Add("", v["ModifierName"], v["Tier"], v["Detail"], v["Rating"], v["FindText"])
}

; ─────────────────────────────────────────────────────────────────────────────
; Helper – read all five fields from a ListView row into an object
; ─────────────────────────────────────────────────────────────────────────────
UltimatumGetRowData(lv, row) {
    return {
        name:   lv.GetText(row, 1),
        tier:   lv.GetText(row, 2),
        detail: lv.GetText(row, 3),
        rating: lv.GetText(row, 4),
        ft:     lv.GetText(row, 5)
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Double-click a row → open the row editor dialog
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLVEdit(ctrl, rowNum, *) {
    global UltimatumLV
    if !rowNum
        return

    d := UltimatumGetRowData(UltimatumLV, rowNum)

    e := Gui()
    e.Opt("+AlwaysOnTop -MinimizeBox")
    e.Title := "Edit Ultimatum Modifier"

    e.Add("Text",  "Section",          "Modifier Name:")
    eName   := e.Add("Edit",  "xs y+3 w240",  d.name)
    e.Add("Text",  "xs y+8",           "Tier:")
    eTier   := e.Add("Edit",  "xs y+3 w80",   d.tier)
    e.Add("Text",  "xs y+8",           "Detail:")
    eDetail := e.Add("Edit",  "xs y+3 w380",  d.detail)
    e.Add("Text",  "xs y+8",           "Rating:")
    eRating := e.Add("DropDownList", "xs y+3", ["Easy", "Manageable", "Hard", "Deadly"])
    eRating.Choose(d.rating)
    e.Add("Text",  "xs y+8",           "FindText:")
    eFT     := e.Add("Edit",  "xs y+3 w310 r1", d.ft)
    e.Add("Button", "x+3 yp w65 h20", "Capture").OnEvent("Click", (*) => ft_Start())
    e.Add("Button", "xs y+10 w120 h28", "Save").OnEvent("Click",
        (*) => UltimatumCommitRow(e, rowNum, eName, eTier, eDetail, eRating, eFT))
    e.Add("Button", "x+5 w120 h28", "Delete Row").OnEvent("Click",
        (*) => UltimatumDeleteRow(e, rowNum))
    e.Show()
}

; ─────────────────────────────────────────────────────────────────────────────
; Commit edits from the row editor back into the main ListView
; ─────────────────────────────────────────────────────────────────────────────
UltimatumCommitRow(editGui, rowNum, eName, eTier, eDetail, eRating, eFT, *) {
    global UltimatumLV
    UltimatumLV.Modify(rowNum,, eName.Value, eTier.Value, eDetail.Value, eRating.Text, eFT.Value)
    editGui.Hide()
}

; ─────────────────────────────────────────────────────────────────────────────
; Delete the row being edited
; ─────────────────────────────────────────────────────────────────────────────
UltimatumDeleteRow(editGui, rowNum, *) {
    global UltimatumLV
    editGui.Hide()
    UltimatumLV.Delete(rowNum)
}

; ─────────────────────────────────────────────────────────────────────────────
; Add a blank placeholder row at the bottom
; ─────────────────────────────────────────────────────────────────────────────
UltimatumAddRow(*) {
    global UltimatumLV
    UltimatumLV.Add("", "New Modifier", "1", "", "Easy", "")
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
}

; ─────────────────────────────────────────────────────────────────────────────
; Move selected row one position up
; ─────────────────────────────────────────────────────────────────────────────
UltimatumMoveUp(*) {
    global UltimatumLV
    sel := UltimatumLV.GetNext(0, "F")
    if sel <= 1
        return
    d := UltimatumGetRowData(UltimatumLV, sel)
    UltimatumLV.Delete(sel)
    UltimatumLV.Insert(sel - 1, "", d.name, d.tier, d.detail, d.rating, d.ft)
    UltimatumLV.Modify(sel - 1, "Focus Select")
}

; ─────────────────────────────────────────────────────────────────────────────
; Move selected row one position down
; ─────────────────────────────────────────────────────────────────────────────
UltimatumMoveDown(*) {
    global UltimatumLV
    sel := UltimatumLV.GetNext(0, "F")
    if !sel || sel >= UltimatumLV.GetCount()
        return
    d := UltimatumGetRowData(UltimatumLV, sel)
    UltimatumLV.Delete(sel)
    UltimatumLV.Insert(sel + 1, "", d.name, d.tier, d.detail, d.rating, d.ft)
    UltimatumLV.Modify(sel + 1, "Focus Select")
}

; ─────────────────────────────────────────────────────────────────────────────
; Duplicate selected row and insert the copy immediately below
; ─────────────────────────────────────────────────────────────────────────────
UltimatumDuplicateRow(*) {
    global UltimatumLV
    sel := UltimatumLV.GetNext(0, "F")
    if !sel
        return
    d := UltimatumGetRowData(UltimatumLV, sel)
    UltimatumLV.Insert(sel + 1, "", d.name, d.tier, d.detail, d.rating, d.ft)
    UltimatumLV.Modify(sel + 1, "Focus Select")
}

; ─────────────────────────────────────────────────────────────────────────────
; Test Detection – capture full screen with FindText, search each row's string,
; optionally flash highlights and display the captured screenshot.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumTestDetection(*) {
    global UltimatumLV, YesUltimatumShowHighlight, YesUltimatumShowScreenshot

    ; Optionally save a screenshot for display after detection
    tempImg := ""
    if YesUltimatumShowScreenshot {
        tempImg := A_Temp "\WR_UltimatumDebug.PNG"
        pToken  := Gdip_Startup()
        pBitmap := Gdip_BitmapFromScreen(0)
        Gdip_SaveBitmapToFile(pBitmap, tempImg)
        Gdip_DisposeImage(pBitmap)
    }

    ; Capture full screen once; reuse cached frame for all FindText calls
    FindText().ScreenShot(0, 0, A_ScreenWidth, A_ScreenHeight)

    total := UltimatumLV.GetCount()
    found := 0
    Loop total {
        ftStr := UltimatumLV.GetText(A_Index, 5)
        if ftStr = ""
            continue
        outX := "", outY := ""
        ok := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight, 0.1, 0.1, ftStr, 0)
        if ok {
            found++
            if YesUltimatumShowHighlight
                MouseTip(ok[1].1, ok[1].2, ok[1].3, ok[1].4)
        }
    }

    ToolTip("Ultimatum Detection: " found "/" total " icons found")
    SetTimer(() => ToolTip(), -2000)

    if tempImg != "" {
        sGui := Gui()
        sGui.Opt("+AlwaysOnTop")
        sGui.Title := "Ultimatum Detection Screenshot"
        sGui.Add("Picture", "w1280 h720", tempImg)
        sGui.Show()
    }
}

UltimatumSaveHighlight(cb, *) {
    global YesUltimatumShowHighlight
    YesUltimatumShowHighlight := cb.Value
    IniWrite(YesUltimatumShowHighlight, A_ScriptDir "\save\Settings.ini", "Automation", "YesUltimatumShowHighlight")
}

UltimatumSaveScreenshot(cb, *) {
    global YesUltimatumShowScreenshot
    YesUltimatumShowScreenshot := cb.Value
    IniWrite(YesUltimatumShowScreenshot, A_ScriptDir "\save\Settings.ini", "Automation", "YesUltimatumShowScreenshot")
}

; ─────────────────────────────────────────────────────────────────────────────
; Collect ListView rows into WR.UltimatumMods.Modifiers
; ─────────────────────────────────────────────────────────────────────────────
UltimatumCollectRows() {
    global UltimatumLV, WR
    WR.UltimatumMods.Modifiers := []
    Loop UltimatumLV.GetCount() {
        WR.UltimatumMods.Modifiers.Push({
            ModifierName: UltimatumLV.GetText(A_Index, 1),
            Tier:         UltimatumLV.GetText(A_Index, 2),
            Detail:       UltimatumLV.GetText(A_Index, 3),
            Rating:       UltimatumLV.GetText(A_Index, 4),
            FindText:     UltimatumLV.GetText(A_Index, 5)
        })
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Persist the current ListView rows to a user-chosen JSON file
; ─────────────────────────────────────────────────────────────────────────────
UltimatumSaveJson(*) {
    global UltimatumLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    UltimatumCollectRows()
    saveDir := A_ScriptDir "\save\automation\ultimatum"
    DirCreate(saveDir)
    SplitPath(UltimatumModsJsonPath, &shortName)
    savePath := FileSelect("S16", saveDir "\" shortName, "Save Modifier Json", "JSON Files (*.json)")
    if savePath = ""
        return
    FileDelete(savePath)
    FileAppend(JSON.Dump(WR.UltimatumMods.Modifiers,, 2), savePath)
    UltimatumModsJsonPath := savePath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}

; ─────────────────────────────────────────────────────────────────────────────
; Load the bundled default JSON without a file-selection dialog
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadDefaults(*) {
    global UltimatumLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    defaultPath := A_ScriptDir "\data\default save data\automation\ultimatum\default_UltimatumMods.json"
    UltimatumLoadFromPath(defaultPath)
    UltimatumModsJsonPath := defaultPath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    UltimatumLV.Delete()
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}

; ─────────────────────────────────────────────────────────────────────────────
; Load modifier rows from a user-selected JSON file
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadJson(*) {
    global UltimatumLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    saveDir := A_ScriptDir "\save\automation\ultimatum"
    DirCreate(saveDir)
    loadPath := FileSelect(1, saveDir "\", "Load Modifier Json", "JSON Files (*.json)")
    if loadPath = ""
        return
    try
        obj := JSON.Load(FileOpen(loadPath, "r").Read())
    catch as e {
        MsgBox("Error loading Ultimatum mods: " e.Message, "Error", "IconX")
        return
    }
    WR.UltimatumMods.Modifiers := obj
    UltimatumModsJsonPath := loadPath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    UltimatumLV.Delete()
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}
