; Ultimatum Modifier Manager GUI

UltimatumLoadFromPath(path) {
    global WR
    if !FileExist(path)
        return
    try
        obj := JSON.Load(FileOpen(path, "r").Read())
    catch
        return
    ; Legacy format: bare array of modifiers
    ; Current format: { "Modifiers": [...], "TierLevels": [...] }
    if obj is Array {
        WR.UltimatumMods.Modifiers  := obj
        WR.UltimatumMods.TierLevels := []
    } else {
        WR.UltimatumMods.Modifiers  := obj.Has("Modifiers")  ? obj["Modifiers"]  : []
        WR.UltimatumMods.TierLevels := obj.Has("TierLevels") ? obj["TierLevels"] : []
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Open / Rebuild the Ultimatum Modifier Manager window
; ─────────────────────────────────────────────────────────────────────────────
UltimatumModsUI(*) {
    global UltimatumUI, UltimatumLV, UltimatumTierLV, UltimatumFileLbl
    global WR, UltimatumModsJsonPath
    global YesUltimatumShowHighlight, YesUltimatumShowScreenshot

    UltimatumUI := Gui()
    UltimatumUI.Opt("+AlwaysOnTop -MinimizeBox")
    UltimatumUI.Title := "Ultimatum Modifier Manager"

    UltimatumLV := UltimatumUI.Add("ListView", "w950 h400 -wrap -Multi Grid",
        ["Modifier Name", "Tier1", "Tier2", "Tier3", "Tier4", "Detail", "FindText"])
    UltimatumLV.OnEvent("DoubleClick", UltimatumLVEdit)
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")

    ; Second table – Tier Levels
    UltimatumTierLV := UltimatumUI.Add("ListView", "xs y+10 w400 h150 -wrap -Multi Grid",
        ["Tier Level", "FindText"])
    UltimatumTierLV.OnEvent("DoubleClick", UltimatumTierLVEdit)
    UltimatumRefreshTierList()
    Loop UltimatumTierLV.GetCount("Column")
        UltimatumTierLV.ModifyCol(A_Index, "AutoHdr")
    UltimatumUI.Add("Button", "xs y+5 w130 h28", "Add Tier Level").OnEvent("Click", UltimatumAddTierLevel)

    ; Row 1 – persistence buttons + loaded-file label
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumUI.Add("Button", "xs y+10 w160 h30", "Save Modifier Json").OnEvent("Click", UltimatumSaveJson)
    UltimatumUI.Add("Button", "w160 h30 x+5", "Load Modifier Json").OnEvent("Click", UltimatumLoadJson)
    UltimatumUI.Add("Button", "w120 h30 x+5", "Load Defaults").OnEvent("Click",      UltimatumLoadDefaults)
    UltimatumFileLbl := UltimatumUI.Add("Text", "x+10 yp+8 w400", shortName)

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
    get(m, k) => (m.Has(k) ? m[k] : "")
    for k, v in WR.UltimatumMods.Modifiers
        UltimatumLV.Add("",
            get(v, "ModifierName"),
            get(v, "Tier1"),
            get(v, "Tier2"),
            get(v, "Tier3"),
            get(v, "Tier4"),
            get(v, "Detail"),
            get(v, "FindText"))
}

; ─────────────────────────────────────────────────────────────────────────────
; Populate the Tier-Levels ListView from WR.UltimatumMods.TierLevels
; ─────────────────────────────────────────────────────────────────────────────
UltimatumRefreshTierList() {
    global UltimatumTierLV, WR
    get(m, k) => (m.Has(k) ? m[k] : "")
    for k, v in WR.UltimatumMods.TierLevels
        UltimatumTierLV.Add("", get(v, "TierLevel"), get(v, "FindText"))
}

; ─────────────────────────────────────────────────────────────────────────────
; Double-click a Tier-Levels row → open the row editor dialog
; ─────────────────────────────────────────────────────────────────────────────
UltimatumTierLVEdit(ctrl, rowNum, *) {
    global UltimatumTierLV
    if !rowNum
        return

    tierLevel := UltimatumTierLV.GetText(rowNum, 1)
    ftStr     := UltimatumTierLV.GetText(rowNum, 2)

    e := Gui()
    e.Opt("+AlwaysOnTop -MinimizeBox")
    e.Title := "Edit Tier Level"

    e.Add("Text",  "Section",          "Tier Level:")
    eTL := e.Add("Edit",  "xs y+3 w240",  tierLevel)

    e.Add("Text",  "xs y+8",           "FindText:")
    eFT := e.Add("Edit",  "xs y+3 w310 r1", ftStr)
    e.Add("Button", "x+3 yp w65 h20", "Capture").OnEvent("Click", (*) => ft_Start())
    e.Add("Button", "xs y+10 w120 h28", "Save").OnEvent("Click",
        (*) => UltimatumCommitTier(e, rowNum, eTL, eFT))
    e.Add("Button", "x+5 w120 h28", "Delete Row").OnEvent("Click",
        (*) => UltimatumDeleteTier(e, rowNum))
    e.Show()
}

UltimatumCommitTier(editGui, rowNum, eTL, eFT, *) {
    global UltimatumTierLV
    UltimatumTierLV.Modify(rowNum,, eTL.Value, eFT.Value)
    editGui.Hide()
}

UltimatumDeleteTier(editGui, rowNum, *) {
    global UltimatumTierLV
    editGui.Hide()
    UltimatumTierLV.Delete(rowNum)
}

UltimatumAddTierLevel(*) {
    global UltimatumTierLV
    UltimatumTierLV.Add("", "New Tier", "")
    Loop UltimatumTierLV.GetCount("Column")
        UltimatumTierLV.ModifyCol(A_Index, "AutoHdr")
}

; ─────────────────────────────────────────────────────────────────────────────
; Collect Tier-Levels ListView rows into WR.UltimatumMods.TierLevels
; ─────────────────────────────────────────────────────────────────────────────
UltimatumCollectTierLevels() {
    global UltimatumTierLV, WR
    WR.UltimatumMods.TierLevels := []
    Loop UltimatumTierLV.GetCount() {
        m := Map()
        m["TierLevel"] := UltimatumTierLV.GetText(A_Index, 1)
        m["FindText"]  := UltimatumTierLV.GetText(A_Index, 2)
        WR.UltimatumMods.TierLevels.Push(m)
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Helper – read all five fields from a ListView row into an object
; ─────────────────────────────────────────────────────────────────────────────
UltimatumGetRowData(lv, row) {
    return {
        name:   lv.GetText(row, 1),
        t1:     lv.GetText(row, 2),
        t2:     lv.GetText(row, 3),
        t3:     lv.GetText(row, 4),
        t4:     lv.GetText(row, 5),
        detail: lv.GetText(row, 6),
        ft:     lv.GetText(row, 7)
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

    ratings := ["Easy", "Manageable", "Hard", "Deadly", "N/A"]

    e.Add("Text",  "Section",          "Modifier Name:")
    eName   := e.Add("Edit",  "xs y+3 w380",  d.name)

    e.Add("Text",  "xs y+8",           "Tier 1:")
    e.Add("Text",  "xs+95 yp",         "Tier 2:")
    e.Add("Text",  "xs+190 yp",        "Tier 3:")
    e.Add("Text",  "xs+285 yp",        "Tier 4:")
    eT1 := e.Add("DropDownList", "xs y+3 w90",   ratings)
    eT1.Choose(d.t1 = "" ? "Easy" : d.t1)
    eT2 := e.Add("DropDownList", "x+5 yp w90",   ratings)
    eT2.Choose(d.t2 = "" ? "Easy" : d.t2)
    eT3 := e.Add("DropDownList", "x+5 yp w90",   ratings)
    eT3.Choose(d.t3 = "" ? "Easy" : d.t3)
    eT4 := e.Add("DropDownList", "x+5 yp w90",   ratings)
    eT4.Choose(d.t4 = "" ? "Easy" : d.t4)

    e.Add("Text",  "xs y+8",           "Detail:")
    eDetail := e.Add("Edit",  "xs y+3 w380 r4 Multi WantReturn +VScroll",  d.detail)

    e.Add("Text",  "xs y+8",           "FindText:")
    eFT     := e.Add("Edit",  "xs y+3 w310 r1", d.ft)
    e.Add("Button", "x+3 yp w65 h20", "Capture").OnEvent("Click", (*) => ft_Start())
    e.Add("Button", "xs y+10 w120 h28", "Save").OnEvent("Click",
        (*) => UltimatumCommitRow(e, rowNum, eName, eT1, eT2, eT3, eT4, eDetail, eFT))
    e.Add("Button", "x+5 w120 h28", "Delete Row").OnEvent("Click",
        (*) => UltimatumDeleteRow(e, rowNum))
    e.Show()
}

; ─────────────────────────────────────────────────────────────────────────────
; Commit edits from the row editor back into the main ListView
; ─────────────────────────────────────────────────────────────────────────────
UltimatumCommitRow(editGui, rowNum, eName, eT1, eT2, eT3, eT4, eDetail, eFT, *) {
    global UltimatumLV
    UltimatumLV.Modify(rowNum,, eName.Value, eT1.Text, eT2.Text, eT3.Text, eT4.Text, eDetail.Value, eFT.Value)
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
    UltimatumLV.Add("", "New Modifier", "Easy", "Easy", "Easy", "Easy", "", "")
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
    UltimatumLV.Insert(sel - 1, "", d.name, d.t1, d.t2, d.t3, d.t4, d.detail, d.ft)
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
    UltimatumLV.Insert(sel + 1, "", d.name, d.t1, d.t2, d.t3, d.t4, d.detail, d.ft)
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
    UltimatumLV.Insert(sel + 1, "", d.name, d.t1, d.t2, d.t3, d.t4, d.detail, d.ft)
    UltimatumLV.Modify(sel + 1, "Focus Select")
}

; ─────────────────────────────────────────────────────────────────────────────
; Test Detection – capture full screen with FindText, search each row's string,
; optionally flash highlights and display the captured screenshot.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumTestDetection(*) {
    global UltimatumLV, UltimatumTierLV, YesUltimatumShowHighlight, YesUltimatumShowScreenshot

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

    matches := []   ; in-memory only – never persisted
    total   := UltimatumLV.GetCount() + UltimatumTierLV.GetCount()
    found   := 0

    ; Scan Modifier table (FindText is column 7)
    Loop UltimatumLV.GetCount() {
        name  := UltimatumLV.GetText(A_Index, 1)
        ftStr := UltimatumLV.GetText(A_Index, 7)
        if ftStr = ""
            continue
        outX := "", outY := ""
        ok := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight, 0.2, 0.1, ftStr, 0)
        if ok {
            found++
            if YesUltimatumShowHighlight
                MouseTip(ok[1].1, ok[1].2, ok[1].3, ok[1].4)
            matches.Push({source: "Modifier", name: name
                , x: ok[1].1, y: ok[1].2, w: ok[1].3, h: ok[1].4})
        }
    }

    ; Scan Tier-Levels table (FindText is column 2)
    Loop UltimatumTierLV.GetCount() {
        name  := UltimatumTierLV.GetText(A_Index, 1)
        ftStr := UltimatumTierLV.GetText(A_Index, 2)
        if ftStr = ""
            continue
        outX := "", outY := ""
        ok := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight, 0.1, 0.1, ftStr, 0)
        if ok {
            found++
            if YesUltimatumShowHighlight
                MouseTip(ok[1].1, ok[1].2, ok[1].3, ok[1].4)
            matches.Push({source: "TierLevel", name: name
                , x: ok[1].1, y: ok[1].2, w: ok[1].3, h: ok[1].4})
        }
    }

    ToolTip("Ultimatum Detection: " found "/" total " icons found")
    SetTimer(() => ToolTip(), -2000)

    UltimatumShowMatches(matches)

    if tempImg != "" {
        sGui := Gui()
        sGui.Opt("+AlwaysOnTop")
        sGui.Title := "Ultimatum Detection Screenshot"
        sGui.Add("Picture", "w1280 h720", tempImg)
        sGui.Show()
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Show the in-memory list of FindText matches from the last Test Detection.
; Double-click any row to re-flash MouseTip on the stored coordinates.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumShowMatches(matches) {
    global UltimatumMatchesUI, UltimatumMatchesLV

    try UltimatumMatchesUI.Destroy()

    UltimatumMatchesUI := Gui()
    UltimatumMatchesUI.Opt("+AlwaysOnTop")
    UltimatumMatchesUI.Title := "Ultimatum Detection Matches (debug, in-memory only)"

    UltimatumMatchesLV := UltimatumMatchesUI.Add("ListView",
        "w560 h300 -wrap -Multi Grid", ["Source", "Name", "X", "Y", "W", "H"])
    UltimatumMatchesLV.OnEvent("DoubleClick", UltimatumMatchClick)

    for k, m in matches
        UltimatumMatchesLV.Add("", m.source, m.name, m.x, m.y, m.w, m.h)

    Loop UltimatumMatchesLV.GetCount("Column")
        UltimatumMatchesLV.ModifyCol(A_Index, "AutoHdr")

    UltimatumMatchesUI.Add("Text", "y+5", "Double-click a row to flash its highlight box.")
    UltimatumMatchesUI.Show()
}

UltimatumMatchClick(ctrl, rowNum, *) {
    global UltimatumMatchesLV
    if !rowNum
        return
    x := UltimatumMatchesLV.GetText(rowNum, 3) + 0
    y := UltimatumMatchesLV.GetText(rowNum, 4) + 0
    w := UltimatumMatchesLV.GetText(rowNum, 5) + 0
    h := UltimatumMatchesLV.GetText(rowNum, 6) + 0
    MouseTip(x, y, w, h)
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
        m := Map()
        m["ModifierName"] := UltimatumLV.GetText(A_Index, 1)
        m["Tier1"]        := UltimatumLV.GetText(A_Index, 2)
        m["Tier2"]        := UltimatumLV.GetText(A_Index, 3)
        m["Tier3"]        := UltimatumLV.GetText(A_Index, 4)
        m["Tier4"]        := UltimatumLV.GetText(A_Index, 5)
        m["Detail"]       := UltimatumLV.GetText(A_Index, 6)
        m["FindText"]     := UltimatumLV.GetText(A_Index, 7)
        WR.UltimatumMods.Modifiers.Push(m)
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Persist the current ListView rows to a user-chosen JSON file
; ─────────────────────────────────────────────────────────────────────────────
UltimatumSaveJson(*) {
    global UltimatumLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    UltimatumCollectRows()
    UltimatumCollectTierLevels()
    out := Map()
    out["Modifiers"]  := WR.UltimatumMods.Modifiers
    out["TierLevels"] := WR.UltimatumMods.TierLevels
    saveDir := A_ScriptDir "\save\automation\ultimatum"
    DirCreate(saveDir)
    SplitPath(UltimatumModsJsonPath, &shortName)
    savePath := FileSelect("S16", saveDir "\" shortName, "Save Modifier Json", "JSON Files (*.json)")
    if savePath = ""
        return
    if (FileExist(savepath)) {
        FileDelete(savePath)
    }
    FileAppend(JSON.Dump(out, 2), savePath)
    UltimatumModsJsonPath := savePath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}

; ─────────────────────────────────────────────────────────────────────────────
; Load the bundled default JSON without a file-selection dialog
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadDefaults(*) {
    global UltimatumLV, UltimatumTierLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    defaultPath := A_ScriptDir "\data\default save data\automation\ultimatum\default_UltimatumMods.json"
    UltimatumLoadFromPath(defaultPath)
    UltimatumModsJsonPath := defaultPath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    UltimatumLV.Delete()
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
    UltimatumTierLV.Delete()
    UltimatumRefreshTierList()
    Loop UltimatumTierLV.GetCount("Column")
        UltimatumTierLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}

; ─────────────────────────────────────────────────────────────────────────────
; Load modifier rows from a user-selected JSON file
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadJson(*) {
    global UltimatumLV, UltimatumTierLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    saveDir := A_ScriptDir "\save\automation\ultimatum"
    DirCreate(saveDir)
    loadPath := FileSelect(1, saveDir "\", "Load Modifier Json", "JSON Files (*.json)")
    if loadPath = ""
        return
    try
        UltimatumLoadFromPath(loadPath)
    catch as e {
        MsgBox("Error loading Ultimatum mods: " e.Message, "Error", "IconX")
        return
    }
    UltimatumModsJsonPath := loadPath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    UltimatumLV.Delete()
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
    UltimatumTierLV.Delete()
    UltimatumRefreshTierList()
    Loop UltimatumTierLV.GetCount("Column")
        UltimatumTierLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}
