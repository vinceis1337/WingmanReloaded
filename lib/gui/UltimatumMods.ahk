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
        UltimatumApplyDetectSettings(Map())
    } else {
        WR.UltimatumMods.Modifiers := obj.Has("Modifiers") ? obj["Modifiers"] : []
        WR.UltimatumMods.Icons     := obj.Has("Icons")      ? obj["Icons"]
                                    : obj.Has("TierLevels") ? obj["TierLevels"]
                                    : []
        UltimatumApplyDetectSettings(obj.Has("DetectSettings") ? obj["DetectSettings"] : Map())
    }
}

; ─────────────────────────────────────────────────────────────────────────────
; Merge a JSON-loaded DetectSettings map into WR.UltimatumMods.DetectSettings,
; using defaults for any missing keys. Called from UltimatumLoadFromPath.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumApplyDetectSettings(ds) {
    global WR
    defaults := Map(
        "ButtonYDelta",  100,
        "ButtonLeftDX",  200,
        "ButtonMidDX",   0,
        "ButtonRightDX", 200)
    WR.UltimatumMods.DetectSettings := Map()
    for k, defVal in defaults
        WR.UltimatumMods.DetectSettings[k] := ds.Has(k) ? ds[k] : defVal
}

; ─────────────────────────────────────────────────────────────────────────────
; Open / Rebuild the Ultimatum Modifier Manager window
; ─────────────────────────────────────────────────────────────────────────────
UltimatumModsUI(*) {
    global UltimatumUI, UltimatumLV, UltimatumIconLV, UltimatumFileLbl
    global WR, UltimatumModsJsonPath
    global YesUltimatumShowHighlight, YesUltimatumShowScreenshot, YesUltimatumShowMouseCoords
    global YesUltimatumEmulateAutomation
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
    cbMC := UltimatumUI.Add("CheckBox", "x+8 yp", "Show Mouse Coords")
    cbMC.Value := YesUltimatumShowMouseCoords
    cbMC.OnEvent("Click", (*) => UltimatumSaveMouseCoords(cbMC))
    if YesUltimatumShowMouseCoords
        SetTimer(UltimatumMouseCoordsTick, 50)
    cbEmu := UltimatumUI.Add("CheckBox", "x+8 yp", "Emulate Automation")
    cbEmu.Value := YesUltimatumEmulateAutomation
    cbEmu.OnEvent("Click", (*) => UltimatumSaveEmulate(cbEmu))

    ; FindText sensitivity inputs (err1 = foreground/text, err0 = background)
    UltimatumUI.Add("Text", "xs+5 y+12",   "Err1 (text):")
    eErr1 := UltimatumUI.Add("Edit", "x+3 yp-3 w55", UltimatumErr1)
    eErr1.OnEvent("Change", (*) => UltimatumSaveErr1(eErr1))
    UltimatumUI.Add("Text", "x+15 yp+3",   "Err0 (bg):")
    eErr0 := UltimatumUI.Add("Edit", "x+3 yp-3 w55", UltimatumErr0)
    eErr0.OnEvent("Change", (*) => UltimatumSaveErr0(eErr0))

    ; Detect by Button – alternative detection algorithm that hovers each of
    ; the three on-screen icons (positioned by deltas from one of the known
    ; ultimatum buttons: Begin / Accept Trial / Confirm) and re-runs FindText
    ; on a fresh screenshot per hover. Deltas live in the JSON file with the
    ; Modifier and Icon tables.
    ds := WR.UltimatumMods.DetectSettings
    UltimatumUI.Add("GroupBox", "Section w700 h100 xs y+10", "Detect by Button (scans for Begin / Accept Trial / Confirm)")
    UltimatumUI.Add("Text", "xs+5 ys+22",    "Y Δ:")
    eYD := UltimatumUI.Add("Edit", "x+5 yp-3 w55", ds["ButtonYDelta"])
    eYD.OnEvent("Change", (*) => UltimatumSaveDetectBtnYDelta(eYD))
    UltimatumUI.Add("Text", "x+20 yp+3",     "Left X Δ:")
    eLD := UltimatumUI.Add("Edit", "x+5 yp-3 w55", ds["ButtonLeftDX"])
    eLD.OnEvent("Change", (*) => UltimatumSaveDetectBtnLeftDX(eLD))
    UltimatumUI.Add("Text", "x+15 yp+3",     "Middle X Δ:")
    eMD := UltimatumUI.Add("Edit", "x+5 yp-3 w55", ds["ButtonMidDX"])
    eMD.OnEvent("Change", (*) => UltimatumSaveDetectBtnMidDX(eMD))
    UltimatumUI.Add("Text", "x+15 yp+3",     "Right X Δ:")
    eRD := UltimatumUI.Add("Edit", "x+5 yp-3 w55", ds["ButtonRightDX"])
    eRD.OnEvent("Change", (*) => UltimatumSaveDetectBtnRightDX(eRD))

    UltimatumUI.Add("Button", "xs+5 y+10 w160 h28", "Detect by Button").OnEvent("Click", UltimatumDetectByButton)

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

    ratings := ["Easy", "Manageable", "Hard", "Deadly", "N/A", "Impossible"]

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
        "w700 h300 -wrap -Multi Grid Checked", ["Source", "Name", "X", "Y", "W", "H"])
    UltimatumMatchesLV.OnEvent("DoubleClick", UltimatumMatchClick)

    for k, m in matches
        UltimatumMatchesLV.Add("", m.source, m.name, m.x, m.y, m.w, m.h)

    Loop UltimatumMatchesLV.GetCount("Column")
        UltimatumMatchesLV.ModifyCol(A_Index, "AutoHdr")

    UltimatumMatchesUI.Add("Text", "y+5", "Double-click a row to flash its highlight box.  Tick a row to mark it as a bad detection (visual only).")

    ; Selectable-modifier analysis (Left / Middle / Right) — monospaced so
    ; columns line up visually.
    grouped := UltimatumGroupMatches(matches)
    UltimatumMatchesUI.SetFont("s9", "Consolas")
    UltimatumMatchesUI.Add("Text", "y+10 w700 r3", UltimatumFormatPositionAnalysis(grouped))
    UltimatumMatchesUI.SetFont()

    ; Suggested modifier pick based on Modifier×Tier difficulty.
    decision := UltimatumChooseModifier(grouped)
    UltimatumMatchesUI.Add("Text", "y+10 w700 r3", UltimatumFormatSuggestion(decision))

    UltimatumMatchesUI.Show()
}

; ─────────────────────────────────────────────────────────────────────────────
; Identify the three on-screen modifier choices (Left/Middle/Right) from the
; in-memory match list:
;   1. Find Icon matches whose Name is purely numeric — those are the
;      Tier-number glyphs that label each modifier choice.
;   2. Look for a triplet whose Y values are all within 15px of each other
;      (i.e. they sit on the same horizontal row on screen).
;   3. Sort that triplet by X — least X = Left, highest X = Right, the
;      remaining one = Middle.
;   4. Sort Modifier matches by X and pair them with the tier positions in
;      the same order.
;   5. Anything missing on either side falls back to "Not Found".
; Returns a 3-line monospaced string ready for a Text control.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumAnalyzeSelectable(matches) {
    return UltimatumFormatPositionAnalysis(UltimatumGroupMatches(matches))
}

; ─────────────────────────────────────────────────────────────────────────────
; Build the Left/Middle/Right grouping. Prefers position tags (Detect by
; Button) when present; otherwise derives positions from X-sorted matches
; (Test Detection).
; ─────────────────────────────────────────────────────────────────────────────
UltimatumGroupMatches(matches) {
    hasPos := false
    for _, m in matches {
        if m.HasOwnProp("pos") {
            hasPos := true
            break
        }
    }
    if hasPos
        return UltimatumGroupByPos(matches)

    ; X-coordinate fallback — Test Detection path.
    mods     := []
    numIcons := []
    for _, m in matches {
        if m.source = "Modifier"
            mods.Push(m)
        else if m.source = "Icon" && m.name ~= "^\d+$"
            numIcons.Push(m)
    }

    triple := UltimatumFindYTriplet(numIcons, 15)
    if triple.Length < 3 && numIcons.Length > 0
        triple := numIcons.Clone()

    UltimatumSortByX(triple)
    UltimatumSortByX(mods)

    grouped := Map()
    ; Default Tier is 1 — if the tier glyph wasn't matched on an icon, assume
    ; it's a Tier 1 modifier rather than reporting "Not Found".
    grouped["Left"]   := {tier: "Tier 1", mod: "Not Found"}
    grouped["Middle"] := {tier: "Tier 1", mod: "Not Found"}
    grouped["Right"]  := {tier: "Tier 1", mod: "Not Found"}
    order := ["Left", "Middle", "Right"]

    tLimit := triple.Length < 3 ? triple.Length : 3
    Loop tLimit
        grouped[order[A_Index]].tier := "Tier " triple[A_Index].name

    mLimit := mods.Length < 3 ? mods.Length : 3
    Loop mLimit
        grouped[order[A_Index]].mod := mods[A_Index].name

    return grouped
}

; ─────────────────────────────────────────────────────────────────────────────
; Group `pos`-tagged matches into Left/Middle/Right buckets, taking the first
; numerically-named Icon and the first Modifier seen per position.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumGroupByPos(matches) {
    grouped := Map()
    ; Default Tier is 1 — if the tier glyph wasn't matched on an icon, assume
    ; it's a Tier 1 modifier rather than reporting "Not Found".
    ; `tierFound` tracks whether a real numeric-Icon detection has overridden
    ; the Tier-1 default, so the first real hit wins (not the default).
    grouped["Left"]   := {tier: "Tier 1", mod: "Not Found", tierFound: false}
    grouped["Middle"] := {tier: "Tier 1", mod: "Not Found", tierFound: false}
    grouped["Right"]  := {tier: "Tier 1", mod: "Not Found", tierFound: false}
    for _, m in matches {
        if !m.HasOwnProp("pos") || !grouped.Has(m.pos)
            continue
        bucket := grouped[m.pos]
        if m.source = "Icon" && m.name ~= "^\d+$" && !bucket.tierFound {
            bucket.tier := "Tier " m.name
            bucket.tierFound := true
        } else if m.source = "Modifier" && bucket.mod = "Not Found" {
            bucket.mod := m.name
        }
    }
    return grouped
}

UltimatumFormatPositionAnalysis(grouped) {
    fmt := "{:-25} ---- {:-25} ---- {:-25}"
    return Format(fmt, "Left Modifier", "Middle Modifier", "Right Modifier")
         . "`n" . Format(fmt, grouped["Left"].tier, grouped["Middle"].tier, grouped["Right"].tier)
         . "`n" . Format(fmt, grouped["Left"].mod,  grouped["Middle"].mod,  grouped["Right"].mod)
}

; ─────────────────────────────────────────────────────────────────────────────
; Difficulty ranking for the user-configured Tier columns. Lower = easier.
; Anything outside the four "viable" ratings is treated as unviable.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumDifficultyRank(diff) {
    static ranks := Map(
        "Easy",       1,
        "Manageable", 2,
        "Hard",       3,
        "Deadly",     4,
        "N/A",        99,
        "Impossible", 99)
    return ranks.Has(diff) ? ranks[diff] : 99
}

; Walk the Modifier ListView; for the row whose Name = modName, return the
; TierN cell that matches tierStr ("Tier 1" .. "Tier 4"). "" if not found.
UltimatumLookupTierDifficulty(modName, tierStr) {
    global UltimatumLV
    if !RegExMatch(tierStr, "(\d+)", &mm)
        return ""
    tierNum := mm[1] + 0
    if tierNum < 1 || tierNum > 4
        return ""
    colIdx := tierNum + 1  ; ListView col layout: 1=name, 2=Tier1 .. 5=Tier4
    Loop UltimatumLV.GetCount() {
        if UltimatumLV.GetText(A_Index, 1) = modName
            return UltimatumLV.GetText(A_Index, colIdx)
    }
    return ""
}

; ─────────────────────────────────────────────────────────────────────────────
; Decide which on-screen modifier to pick given the Left/Middle/Right group.
; Returns:
;   { takeReward: true,  winners: [], candidates: [...] }   ; all unviable
;   { takeReward: false, winners: [ {pos, mod, tier, diff}, ... ], candidates: [...] }
;     – one entry per tied lowest-rank viable position.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumChooseModifier(grouped) {
    order := ["Left", "Middle", "Right"]
    parseTier(s) {
        if RegExMatch(s, "(\d+)", &m)
            return m[1] + 0
        return 99
    }
    candidates := []
    for _, posName in order {
        if !grouped.Has(posName)
            continue
        info := grouped[posName]
        diff := UltimatumLookupTierDifficulty(info.mod, info.tier)
        candidates.Push({pos: posName, mod: info.mod, tier: info.tier
            , diff: diff, rank: UltimatumDifficultyRank(diff), tierNum: parseTier(info.tier)})
    }

    ; If no viable candidate exists (every rank ≥ 99) suggest Take Reward.
    minRank := 99
    for _, c in candidates {
        if c.rank < minRank
            minRank := c.rank
    }
    if minRank >= 99
        return {takeReward: true, winners: [], candidates: candidates}

    ; First pass: filter to candidates at the lowest difficulty rank.
    rankWinners := []
    for _, c in candidates {
        if c.rank = minRank
            rankWinners.Push(c)
    }

    ; Tie-break: among those, prefer the lowest tier number. Any remaining
    ; ties (same difficulty AND same tier) stay tied.
    minTier := 99
    for _, c in rankWinners {
        if c.tierNum < minTier
            minTier := c.tierNum
    }
    winners := []
    for _, c in rankWinners {
        if c.tierNum = minTier
            winners.Push(c)
    }
    return {takeReward: false, winners: winners, candidates: candidates}
}

UltimatumFormatSuggestion(decision) {
    if decision.takeReward {
        return "Suggestion: Take Reward — every modifier is Impossible / N/A."
    }
    fmtOne(w) => w.pos " — " w.mod " (" w.tier ", " (w.diff = "" ? "?" : w.diff) ")"
    if decision.winners.Length = 1
        return "Suggestion: " fmtOne(decision.winners[1])

    parts := []
    for _, w in decision.winners
        parts.Push(fmtOne(w))
    return "Tied — pick any:`n  " UltimatumJoin(parts, "`n  ")
}

UltimatumJoin(arr, sep) {
    s := ""
    for k, v in arr
        s .= (k > 1 ? sep : "") . v
    return s
}

; ─────────────────────────────────────────────────────────────────────────────
; Y-triplet finder: returns the first 3 items (Y-sorted) whose Y values are
; within `maxDistY` pixels of each other, or an empty array if none exist.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumFindYTriplet(items, maxDistY) {
    if items.Length < 3
        return []
    sorted := items.Clone()
    UltimatumSortByY(sorted)
    Loop sorted.Length - 2 {
        i := A_Index
        if (sorted[i+2].y - sorted[i].y) <= maxDistY
            return [sorted[i], sorted[i+1], sorted[i+2]]
    }
    return []
}

; In-place bubble sorts (the arrays are tiny — ≤ a few dozen entries).
UltimatumSortByX(arr) {
    n := arr.Length
    if n < 2
        return
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (arr[j].x > arr[j+1].x) {
                tmp := arr[j]
                arr[j] := arr[j+1]
                arr[j+1] := tmp
            }
        }
    }
}

UltimatumSortByY(arr) {
    n := arr.Length
    if n < 2
        return
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (arr[j].y > arr[j+1].y) {
                tmp := arr[j]
                arr[j] := arr[j+1]
                arr[j+1] := tmp
            }
        }
    }
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

UltimatumSaveMouseCoords(cb, *) {
    global YesUltimatumShowMouseCoords
    YesUltimatumShowMouseCoords := cb.Value
    IniWrite(YesUltimatumShowMouseCoords, A_ScriptDir "\save\Settings.ini", "Automation", "YesUltimatumShowMouseCoords")
    if cb.Value {
        SetTimer(UltimatumMouseCoordsTick, 50)
    } else {
        SetTimer(UltimatumMouseCoordsTick, 0)
        ToolTip(,,, 3)
    }
}

; Debug tick: prints the current mouse position to ToolTip ID 3 (separate
; from the default ToolTip and from the match-click notification on ID 2).
UltimatumMouseCoordsTick() {
    MouseGetPos(&mx, &my)
    ToolTip("X: " mx "  Y: " my, mx + 15, my + 15, 3)
}

UltimatumSaveEmulate(cb, *) {
    global YesUltimatumEmulateAutomation
    YesUltimatumEmulateAutomation := cb.Value
    IniWrite(YesUltimatumEmulateAutomation, A_ScriptDir "\save\Settings.ini", "Automation", "YesUltimatumEmulateAutomation")
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

; The four delta inputs update WR.UltimatumMods.DetectSettings in-memory.
; Their values land in the JSON file the next time the user clicks
; "Save Modifier Json".
UltimatumSaveDetectBtnYDelta(ctrl, *) {
    global WR
    WR.UltimatumMods.DetectSettings["ButtonYDelta"] := ctrl.Value
}
UltimatumSaveDetectBtnLeftDX(ctrl, *) {
    global WR
    WR.UltimatumMods.DetectSettings["ButtonLeftDX"] := ctrl.Value
}
UltimatumSaveDetectBtnMidDX(ctrl, *) {
    global WR
    WR.UltimatumMods.DetectSettings["ButtonMidDX"] := ctrl.Value
}
UltimatumSaveDetectBtnRightDX(ctrl, *) {
    global WR
    WR.UltimatumMods.DetectSettings["ButtonRightDX"] := ctrl.Value
}

; ─────────────────────────────────────────────────────────────────────────────
; Look up the FindText pattern for a row Named `searchName`. Checks the
; Modifier table first (column 7) then the Icon table (column 2). Returns
; "" if not found.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumLookupFindText(searchName) {
    global UltimatumLV, UltimatumIconLV
    Loop UltimatumLV.GetCount() {
        if UltimatumLV.GetText(A_Index, 1) = searchName
            return UltimatumLV.GetText(A_Index, 7)
    }
    Loop UltimatumIconLV.GetCount() {
        if UltimatumIconLV.GetText(A_Index, 1) = searchName
            return UltimatumIconLV.GetText(A_Index, 2)
    }
    return ""
}

; ─────────────────────────────────────────────────────────────────────────────
; Detect by Button:
;   1. FindText the button row whose Name = UltimatumDetectBtnName.
;   2. For each of the three icon positions (Left/Middle/Right) — computed
;      as button.x + ΔX and button.y + YΔ — mouse over the spot, sleep so
;      the in-game tooltip can render, take a fresh FindText screenshot, and
;      run FindText against:
;        - every numerically-named Icon row (tier glyphs), and
;        - every Modifier row's FindText.
;   3. Each hit is pushed into the matches array tagged with `pos` so the
;      bottom-panel analyzer can group them by Left/Middle/Right directly
;      instead of inferring position from X.
;   4. Open the standard Ultimatum Detection Matches window.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumDetectByButton(*) {
    global UltimatumLV, UltimatumIconLV, UltimatumErr1, UltimatumErr0, WR
    global YesUltimatumEmulateAutomation, UltimatumLastEmulateTick

    ; While emulating, throttle re-entry to once every 3 seconds so a held
    ; / spammed trigger can't run multiple cycles back-to-back.
    if YesUltimatumEmulateAutomation {
        if (A_TickCount - UltimatumLastEmulateTick) < 3000
            return
        UltimatumLastEmulateTick := A_TickCount
    }

    ; Try each known ultimatum button in turn; use the first one whose
    ; FindText pattern (looked up by Name) is present on screen.
    btnNames := ["Begin", "Accept Trial", "Confirm"]
    foundName := "", btnCenterX := 0, btnCenterY := 0
    for _, bn in btnNames {
        ftStr := UltimatumLookupFindText(bn)
        if ftStr = ""
            continue
        outX := "", outY := ""
        btn := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight
            , UltimatumErr1, UltimatumErr0, ftStr)
        if btn {
            foundName  := bn
            btnCenterX := btn[1].x
            btnCenterY := btn[1].y
            break
        }
    }

    if foundName = "" {
        ; 0x40000 = MB_TOPMOST so the dialog stays above the game and other
        ; windows that might steal focus on hover.
        MsgBox("None of [Begin, Accept Trial, Confirm] were found on screen.`n`nMake sure each has a row in the Modifier or Icon tables with a FindText pattern."
             , "Detect by Button", "IconX 0x40000")
        return
    }

    ; All four inputs are positive magnitudes. Y Δ is subtracted because the
    ; icons sit above the button, Left X Δ is subtracted because it sits to
    ; the left, Middle/Right X Δ are added.
    ds := WR.UltimatumMods.DetectSettings
    leftDX  := ds["ButtonLeftDX"]  + 0
    midDX   := ds["ButtonMidDX"]   + 0
    rightDX := ds["ButtonRightDX"] + 0
    yDelta  := ds["ButtonYDelta"]  + 0

    positions := [{name: "Left",   x: btnCenterX - leftDX}
                , {name: "Middle", x: btnCenterX + midDX}
                , {name: "Right",  x: btnCenterX + rightDX}]

    ; Scan region: 800×800 square anchored to the bottom-center of the
    ; button (400px to each side, 800px upward). Used for both the Icon
    ; and the Modifier FindText loops.
    scanRectX1 := btnCenterX - 400
    scanRectY1 := btnCenterY - 800
    scanRectX2 := btnCenterX + 400
    scanRectY2 := btnCenterY

    matches := []
    for _, pos in positions {
        iconX := pos.x
        iconY := btnCenterY - yDelta

        MouseMove(iconX, iconY, 0)
        Sleep(300)  ; let the in-game tooltip render

        ; Fresh screenshot for this hover state; subsequent FindText calls
        ; use the cached frame (ScreenShot = 0).
        FindText().ScreenShot(0, 0, A_ScreenWidth, A_ScreenHeight)

        ; Search every numerically-named Icon row (the tier glyphs) within
        ; the 800×800 region above the button.
        Loop UltimatumIconLV.GetCount() {
            name := UltimatumIconLV.GetText(A_Index, 1)
            if !(name ~= "^\d+$")
                continue
            ftStr := UltimatumIconLV.GetText(A_Index, 2)
            if ftStr = ""
                continue
            outX := "", outY := ""
            ok := FindText(&outX, &outY, scanRectX1, scanRectY1, scanRectX2, scanRectY2
                , UltimatumErr1, UltimatumErr0, ftStr, 0, 1)
            if ok {
                for _, m in ok
                    matches.Push({source: "Icon", name: name, pos: pos.name
                        , x: m.1, y: m.2, w: m.3, h: m.4})
            }
        }

        ; Search every Modifier row within the same 800×800 region above
        ; the button.
        Loop UltimatumLV.GetCount() {
            name  := UltimatumLV.GetText(A_Index, 1)
            ftStr := UltimatumLV.GetText(A_Index, 7)
            if ftStr = ""
                continue
            outX := "", outY := ""
            ok := FindText(&outX, &outY, scanRectX1, scanRectY1, scanRectX2, scanRectY2
                , UltimatumErr1, UltimatumErr0, ftStr, 0)
            if ok {
                matches.Push({source: "Modifier", name: name, pos: pos.name
                    , x: ok[1].1, y: ok[1].2, w: ok[1].3, h: ok[1].4})
            }
        }
    }

    if YesUltimatumEmulateAutomation {
        UltimatumEmulateChoice(matches, positions, btnCenterX, btnCenterY, yDelta)
        return
    }

    UltimatumShowMatches(matches)
}

; ─────────────────────────────────────────────────────────────────────────────
; Emulate Automation path — invoked from UltimatumDetectByButton when the
; Emulate Automation checkbox is on. Does NOT open the matches window;
; instead it picks the suggested modifier (or Take Reward when everything
; is unviable) and clicks it, then clicks the button that anchored the cycle.
;
; If any Left/Middle/Right slot has Modifier = "Not Found", the cycle is
; paused: presses Escape in-game, makes sure the Ultimatum Modifier Manager
; window is visible, and pops an always-on-top MsgBox.
; ─────────────────────────────────────────────────────────────────────────────
UltimatumEmulateChoice(matches, positions, btnCenterX, btnCenterY, yDelta) {
    global UltimatumLV, UltimatumIconLV, UltimatumErr1, UltimatumErr0, UltimatumUI

    grouped := UltimatumGroupByPos(matches)

    ; Pause if any modifier slot wasn't identified.
    for _, posName in ["Left", "Middle", "Right"] {
        if grouped[posName].mod = "Not Found" {
            Send("{Escape}")
            Sleep(50)
            try UltimatumUI.Show()
            MsgBox("Modifier not identified in the " posName " slot. Emulation paused.`n`n"
                 . "Adjust your icon/modifier rows or sensitivity and re-run."
                 , "Emulate Automation", "IconX 0x40000")
            return
        }
    }

    decision := UltimatumChooseModifier(grouped)

    if decision.takeReward {
        trFT := UltimatumLookupFindText("Take Reward")
        if trFT = "" {
            MsgBox("Take Reward FindText not configured (add a row named 'Take Reward')."
                 , "Emulate Automation", "IconX 0x40000")
            return
        }
        outX := "", outY := ""
        tr := FindText(&outX, &outY, 0, 0, A_ScreenWidth, A_ScreenHeight
            , UltimatumErr1, UltimatumErr0, trFT)
        if !tr {
            MsgBox("Take Reward icon was not found on screen.", "Emulate Automation", "IconX 0x40000")
            return
        }
        MouseMove(tr[1].x, tr[1].y, 0)
        Sleep(75)
        Click()
        return
    }

    ; Pick the first tied winner (left-most wins on ties).
    winner := decision.winners[1]
    posIdx := winner.pos = "Left" ? 1 : winner.pos = "Middle" ? 2 : 3
    modX := positions[posIdx].x
    modY := btnCenterY - yDelta

    MouseMove(modX, modY, 0)
    Sleep(75)
    Click()
    Sleep(150)

    MouseMove(btnCenterX, btnCenterY, 0)
    Sleep(75)
    Click()
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
    out["Modifiers"]      := WR.UltimatumMods.Modifiers
    out["Icons"]          := WR.UltimatumMods.Icons
    out["DetectSettings"] := WR.UltimatumMods.DetectSettings
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
