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
    ; Current format: { "Modifiers": [...], "Icons": [...] }
    ; Also accepts legacy "TierLevels" key for the second table.
    if obj is Array {
        WR.UltimatumMods.Modifiers := obj
        WR.UltimatumMods.Icons     := []
    } else {
        WR.UltimatumMods.Modifiers := obj.Has("Modifiers") ? obj["Modifiers"] : []
        WR.UltimatumMods.Icons     := obj.Has("Icons")      ? obj["Icons"]
                                    : obj.Has("TierLevels") ? obj["TierLevels"]
                                    : []
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Open / Rebuild the Ultimatum Modifier Manager window
; ─────────────────────────────────────────────────────────────────────────────
UltimatumModsUI(*) {
    global UltimatumUI, UltimatumLV, UltimatumIconLV, UltimatumFileLbl
    global WR, UltimatumModsJsonPath
    global YesUltimatumShowHighlight, YesUltimatumShowScreenshot
    global UltimatumErr1, UltimatumErr0

    UltimatumUI := Gui()
    UltimatumUI.Opt("+AlwaysOnTop -MinimizeBox")
    UltimatumUI.Title := "Ultimatum Modifier Manager"

    UltimatumLV := UltimatumUI.Add("ListView", "w950 h400 -wrap -Multi Grid",
        ["Modifier Name", "Tier1", "Tier2", "Tier3", "Tier4", "Detail", "FindText"])
    UltimatumLV.OnEvent("DoubleClick", UltimatumLVEdit)
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")

    ; Second table – Icons
    UltimatumIconLV := UltimatumUI.Add("ListView", "xs y+10 w400 h150 -wrap -Multi Grid",
        ["Icon", "FindText"])
    UltimatumIconLV.OnEvent("DoubleClick", UltimatumIconLVEdit)
    UltimatumRefreshIconList()
    Loop UltimatumIconLV.GetCount("Column")
        UltimatumIconLV.ModifyCol(A_Index, "AutoHdr")
    UltimatumUI.Add("Button", "xs y+5 w130 h28", "Add Icon").OnEvent("Click", UltimatumAddIcon)

    ; Row 1 – persistence buttons + loaded-file label
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumUI.Add("Button", "xs y+10 w160 h30", "Save Modifier Json").OnEvent("Click", UltimatumSaveJson)
    UltimatumUI.Add("Button", "w160 h30 x+5", "Load Modifier Json").OnEvent("Click", UltimatumLoadJson)
    UltimatumUI.Add("Button", "w120 h30 x+5", "Load Defaults").OnEvent("Click",      UltimatumLoadDefaults)
    UltimatumFileLbl := UltimatumUI.Add("Text", "x+10 yp+8 w400", shortName)

    ; Row 2 – Debug group
    UltimatumUI.Add("GroupBox", "Section w700 h125 xs y+10", "Debug")
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

    ; FindText sensitivity inputs (err1 = foreground/text, err0 = background)
    UltimatumUI.Add("Text", "xs+5 y+12",   "Err1 (text):")
    eErr1 := UltimatumUI.Add("Edit", "x+3 yp-3 w55", UltimatumErr1)
    eErr1.OnEvent("Change", (*) => UltimatumSaveErr1(eErr1))
    UltimatumUI.Add("Text", "x+15 yp+3",   "Err0 (bg):")
    eErr0 := UltimatumUI.Add("Edit", "x+3 yp-3 w55", UltimatumErr0)
    eErr0.OnEvent("Change", (*) => UltimatumSaveErr0(eErr0))

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
; Populate the Icons ListView from WR.UltimatumMods.Icons
; ─────────────────────────────────────────────────────────────────────────────
UltimatumRefreshIconList() {
    global UltimatumIconLV, WR
    get(m, k1, k2) => (m.Has(k1) ? m[k1] : (m.Has(k2) ? m[k2] : ""))
    for k, v in WR.UltimatumMods.Icons
        UltimatumIconLV.Add("", get(v, "Icon", "TierLevel"), get(v, "FindText", ""))
}

; ─────────────────────────────────────────────────────────────────────────────
; Double-click an Icons row → open the row editor dialog
; ─────────────────────────────────────────────────────────────────────────────
UltimatumIconLVEdit(ctrl, rowNum, *) {
    global UltimatumIconLV
    if !rowNum
        return

    tierLevel := UltimatumIconLV.GetText(rowNum, 1)
    ftStr     := UltimatumIconLV.GetText(rowNum, 2)

    e := Gui()
    e.Opt("+AlwaysOnTop -MinimizeBox")
    e.Title := "Edit Icon"

    e.Add("Text",  "Section",          "Icon:")
    eTL := e.Add("Edit",  "xs y+3 w240",  tierLevel)

    e.Add("Text",  "xs y+8",           "FindText:")
    eFT := e.Add("Edit",  "xs y+3 w310 r1", ftStr)
    e.Add("Button", "x+3 yp w65 h20", "Capture").OnEvent("Click", (*) => ft_Start())
    e.Add("Button", "xs y+10 w120 h28", "Save").OnEvent("Click",
        (*) => UltimatumCommitIcon(e, rowNum, eTL, eFT))
    e.Add("Button", "x+5 w120 h28", "Delete Row").OnEvent("Click",
        (*) => UltimatumDeleteIcon(e, rowNum))
    e.Show()
}

UltimatumCommitIcon(editGui, rowNum, eTL, eFT, *) {
    global UltimatumIconLV
    UltimatumIconLV.Modify(rowNum,, eTL.Value, eFT.Value)
    editGui.Hide()
}

UltimatumDeleteIcon(editGui, rowNum, *) {
    global UltimatumIconLV
    editGui.Hide()
    UltimatumIconLV.Delete(rowNum)
}

UltimatumAddIcon(*) {
    global UltimatumIconLV
    UltimatumIconLV.Add("", "New Icon", "")
    Loop UltimatumIconLV.GetCount("Column")
        UltimatumIconLV.ModifyCol(A_Index, "AutoHdr")
}

; ─────────────────────────────────────────────────────────────────────────────
; Collect Icons ListView rows into WR.UltimatumMods.Icons
; ─────────────────────────────────────────────────────────────────────────────
UltimatumCollectIcons() {
    global UltimatumIconLV, WR
    WR.UltimatumMods.Icons := []
    Loop UltimatumIconLV.GetCount() {
        m := Map()
        m["Icon"]     := UltimatumIconLV.GetText(A_Index, 1)
        m["FindText"] := UltimatumIconLV.GetText(A_Index, 2)
        WR.UltimatumMods.Icons.Push(m)
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
    global UltimatumLV, UltimatumIconLV, YesUltimatumShowHighlight, YesUltimatumShowScreenshot
    global UltimatumErr1, UltimatumErr0

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
    total   := UltimatumLV.GetCount() + UltimatumIconLV.GetCount()
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

    ; Scan Icons table (FindText is column 2) – report every match per row,
    ; since the same Icon typically appears multiple times on screen.
    Loop UltimatumIconLV.GetCount() {
        name  := UltimatumIconLV.GetText(A_Index, 1)
        ftStr := UltimatumIconLV.GetText(A_Index, 2)
        if ftStr = ""
            continue
        outX := "", outY := ""
        ok := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight, UltimatumErr1, UltimatumErr0, ftStr, 0, 1)
        if ok {
            found++
            ; Flash MouseTip on only the first match to avoid a long sequential
            ; flash chain when there are many hits; the rest are clickable in
            ; the Matches debug window.
            if YesUltimatumShowHighlight
                MouseTip(ok[1].1, ok[1].2, ok[1].3, ok[1].4)
            for _, m in ok
                matches.Push({source: "Icon", name: name
                    , x: m.1, y: m.2, w: m.3, h: m.4})
        }
    }

    ToolTip("Ultimatum Detection: " found "/" total " rows matched (" matches.Length " total matches)")
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
        "w560 h300 -wrap -Multi Grid Checked", ["Source", "Name", "X", "Y", "W", "H"])
    UltimatumMatchesLV.OnEvent("DoubleClick", UltimatumMatchClick)

    for k, m in matches
        UltimatumMatchesLV.Add("", m.source, m.name, m.x, m.y, m.w, m.h)

    Loop UltimatumMatchesLV.GetCount("Column")
        UltimatumMatchesLV.ModifyCol(A_Index, "AutoHdr")

    UltimatumMatchesUI.Add("Text", "y+5", "Double-click a row to flash its highlight box.  Tick a row to mark it as a bad detection (visual only).")
    UltimatumMatchesUI.Show()
}

UltimatumMatchClick(ctrl, rowNum, *) {
    global UltimatumMatchesLV
    if !rowNum
        return
    source := UltimatumMatchesLV.GetText(rowNum, 1)
    name   := UltimatumMatchesLV.GetText(rowNum, 2)
    x := UltimatumMatchesLV.GetText(rowNum, 3) + 0
    y := UltimatumMatchesLV.GetText(rowNum, 4) + 0
    w := UltimatumMatchesLV.GetText(rowNum, 5) + 0
    h := UltimatumMatchesLV.GetText(rowNum, 6) + 0
    ; Show notification first; MouseTip blocks during its flash animation
    ; so painting the ToolTip beforehand keeps it visible immediately.
    ; Uses tooltip ID 2 so it doesn't clobber the default ToolTip elsewhere.
    ToolTip("↑ " source ": " name " (highlight box above)", x, y + h + 20, 2)
    SetTimer(() => ToolTip(,,, 2), -5000)
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

UltimatumSaveErr1(ctrl, *) {
    global UltimatumErr1
    UltimatumErr1 := ctrl.Value
    IniWrite(UltimatumErr1, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumErr1")
}

UltimatumSaveErr0(ctrl, *) {
    global UltimatumErr0
    UltimatumErr0 := ctrl.Value
    IniWrite(UltimatumErr0, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumErr0")
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
    UltimatumCollectIcons()
    out := Map()
    out["Modifiers"] := WR.UltimatumMods.Modifiers
    out["Icons"]     := WR.UltimatumMods.Icons
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
    global UltimatumLV, UltimatumIconLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
    defaultPath := A_ScriptDir "\data\default save data\automation\ultimatum\default_UltimatumMods.json"
    UltimatumLoadFromPath(defaultPath)
    UltimatumModsJsonPath := defaultPath
    IniWrite(UltimatumModsJsonPath, A_ScriptDir "\save\Settings.ini", "Automation", "UltimatumModsJsonPath")
    UltimatumLV.Delete()
    UltimatumRefreshList()
    Loop UltimatumLV.GetCount("Column")
        UltimatumLV.ModifyCol(A_Index, "AutoHdr")
    UltimatumIconLV.Delete()
    UltimatumRefreshIconList()
    Loop UltimatumIconLV.GetCount("Column")
        UltimatumIconLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}

; ─────────────────────────────────────────────────────────────────────────────
; Load modifier rows from a user-selected JSON file
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLoadJson(*) {
    global UltimatumLV, UltimatumIconLV, UltimatumFileLbl, WR, UltimatumModsJsonPath
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
    UltimatumIconLV.Delete()
    UltimatumRefreshIconList()
    Loop UltimatumIconLV.GetCount("Column")
        UltimatumIconLV.ModifyCol(A_Index, "AutoHdr")
    SplitPath(UltimatumModsJsonPath, &shortName)
    UltimatumFileLbl.Text := shortName
}
