{
    FaceGen Generator
}
unit FaceGen;

// ----------------------------------------------------
//Create variables that will need to be used accross multiple functions/procedures.
// ----------------------------------------------------

var
    iPluginFile, iRealPlugin: IInterface;
    bBatchMode, bQuickFaceFix, bOnlyMissing, bAll, bNeedPlugin, bUserRulesChanged, bSaveUserRules, bElric: Boolean;
    sCKFixesINI, sVEFSDir, sPicVefs, sResolution, sRealPlugin, sLastRuleType: string;
    tlRace, tlNpc, tlTxst, tlHdpt, tlCopyToReal: TList;
    slModels, slTextures, slMaterials, slAssets, slPluginFiles, slDiffuseTextures, slNormalTextures, slSpecularTextures: TStringList;
    slTintTextures, slResolutions, slNPCRecords, slNPCPlugin, slNPCMatches, slPresetAdd, slPresetRemove, slMissingOnly, slEverything, slCharGenPreset, slFaceGenMode: TStringList;
    rbFaceGenPreset, rbOnlyMissing, rbAll: TRadioButton;
    joFaces, joConfig, joRules, joUserRules: TJsonObject;
    uiScale: integer;

    lvRules: TListView;
    btnRuleOk, btnRuleCancel: TButton;
    cbNPCPlugin: TComboBox;
    cbkey: TComboBox;

const
    sPatchName = 'FaceGenPatch.esp';

// ----------------------------------------------------
// Main functions and procedures go up immediately below.
// ----------------------------------------------------

function Initialize: integer;
{
    This function is called at the beginning.
}
var
    i: integer;
begin
    CreateObjects;
    bNeedPlugin := false;
    sLastRuleType := 'Plugin';

    //Get scaling
    uiScale := Screen.PixelsPerInch * 100 / 96;
    AddMessage('UI scale: ' + IntToStr(uiScale));

    //Used to tell the Rule Editor whether or not to save changes.
    bSaveUserRules := false;
    bUserRulesChanged := false;

    bBatchMode := CheckLaunchArguments;
    FetchRules;
    CollectRecords;

    if not bBatchMode then begin
        if not MainMenuForm then begin
            Result := 1;
            Exit;
        end;
    end;

    if bOnlyMissing then begin
        AddMessage('Mode: Only Missing');
        joConfig.S['Mode'] := 'Only Missing';
    end
    else if bQuickFaceFix then begin
        AddMessage('Mode: Quick Face Fix');
        joConfig.S['Mode'] := 'Quick Face Fix';
    end
    else if bAll then begin
        AddMessage('Mode: All');
        joConfig.S['Mode'] := 'All';
    end;

    if not bQuickFaceFix then begin
        if not RequirementsCheck then begin
            Result := 1;
            Exit;
        end;
        CreateRealPlugin;
    end;

    ProcessRecords;
    CollectAssets;

    Result := 0;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    tlRace.Free;
    tlNpc.Free;
    tlHdpt.Free;
    tlCopyToReal.Free;

    slModels.Free;
    slTextures.Free;
    slMaterials.Free;
    slAssets.Free;
    slPluginFiles.Free;
    slNPCRecords.Free;
    slNPCPlugin.Free;

    slDiffuseTextures.Free;
    slNormalTextures.Free;
    slSpecularTextures.Free;
    slTintTextures.Free;
    slResolutions.Free;
    slNPCMatches.Free;
    slPresetAdd.Free;
    slPresetRemove.Free;
    slMissingOnly.Free;
    slEverything.Free;
    slCharGenPreset.Free;
    slFaceGenMode.Free;

    joRules.Free;
    if bSaveUserRules and bUserRulesChanged then begin
        AddMessage('Saving ' + IntToStr(joUserRules.Count) + ' user rule(s) to ' + sVEFSDir + '\Rules\UserRules.json');
        joUserRules.SaveToFile(sVEFSDir + '\Rules\UserRules.json', False, TEncoding.UTF8, True);
    end;
    joUserRules.Free;
    joConfig.S['NeedPlugin'] := bNeedPlugin;
    joConfig.SaveToFile(sVEFSDir + '\config.json', False, TEncoding.UTF8, True);
    joConfig.Free;
    joFaces.SaveToFile(sVEFSDir + '\Faces.json', False, TEncoding.UTF8, True);
    joFaces.Free;
    Result := 0;
end;

procedure CreateObjects;
begin
    tlRace := TList.Create;
    tlNpc := TList.Create;
    tlHdpt := TList.Create;
    tlCopyToReal := TList.Create;

    slModels := TStringList.Create;
    slModels.Sorted := True;
    slModels.Duplicates := dupIgnore;

    slTextures := TStringList.Create;
    slTextures.Sorted := True;
    slTextures.Duplicates := dupIgnore;

    slDiffuseTextures := TStringList.Create;
    slDiffuseTextures.Sorted := True;
    slDiffuseTextures.Duplicates := dupIgnore;

    slNormalTextures := TStringList.Create;
    slNormalTextures.Sorted := True;
    slNormalTextures.Duplicates := dupIgnore;

    slSpecularTextures := TStringList.Create;
    slSpecularTextures.Sorted := True;
    slSpecularTextures.Duplicates := dupIgnore;

    slTintTextures := TStringList.Create;
    slTintTextures.Sorted := True;
    slTintTextures.Duplicates := dupIgnore;

    slMaterials := TStringList.Create;
    slMaterials.Sorted := True;
    slMaterials.Duplicates := dupIgnore;

    slAssets := TStringList.Create;
    slAssets.Sorted := True;
    slAssets.Duplicates := dupIgnore;

    slNPCRecords := TStringList.Create;
    slNPCRecords.Sorted := True;
    slNPCRecords.Duplicates := dupIgnore;

    slNPCMatches := TStringList.Create;
    slNPCMatches.Sorted := True;
    slNPCMatches.Duplicates := dupIgnore;

    slPresetAdd := TStringList.Create;
    slPresetAdd.Sorted := True;
    slPresetAdd.Duplicates := dupIgnore;

    slPresetRemove := TStringList.Create;
    slPresetRemove.Sorted := True;
    slPresetRemove.Duplicates := dupIgnore;

    slMissingOnly := TStringList.Create;
    slMissingOnly.Sorted := True;
    slMissingOnly.Duplicates := dupIgnore;

    slEverything := TStringList.Create;
    slEverything.Sorted := True;
    slEverything.Duplicates := dupIgnore;

    slPluginFiles := TStringList.Create;

    slCharGenPreset := TStringList.Create;
    slCharGenPreset.Add('Default');
    slCharGenPreset.Add('Never');
    slCharGenPreset.Add('Always');

    slFaceGenMode := TStringList.Create;
    slFaceGenMode.Add('Default');
    slFaceGenMode.Add('Only If Missing');
    slFaceGenMode.Add('Always');


    slResolutions := TStringList.Create;
    slResolutions.Add('512 ');
    slResolutions.Add('1024');
    slResolutions.Add('2048');
    slResolutions.Add('4096');

    slNPCPlugin := TStringList.Create;
    slNPCPlugin.Add('NPC');
    slNPCPlugin.Add('Plugin');


    joFaces := TJsonObject.Create;
    joConfig := TJsonObject.Create;
    joRules := TJsonObject.Create;
    joUserRules := TJsonObject.Create;
end;

// ----------------------------------------------------
// UI functions and procedures go below.
// ----------------------------------------------------

function MainMenuForm: Boolean;
{
    Main menu form.
}
var
    frm: TForm;
    btnStart, btnCancel, btnRuleEditor: TButton;
    pnl: TPanel;
    gbOptions, gbMode: TGroupBox;
    picVefs: TPicture;
    fImage: TImage;
    cbResolution: TComboBox;
    chkElric: TCheckBox;
    edPluginName: TEdit;
    ini: TIniFile;
    bCKPEExists: Boolean;
begin
    bCKPEExists := false;
    if FileExists(GamePath + 'CreationKitPlatformExtended.ini') then begin
        bCKPEExists := true;
        ini := TIniFile.Create(GamePath + 'CreationKitPlatformExtended.ini');
        sResolution := LeftStr(ini.ReadString('FaceGen', 'uTintMaskResolution', '2048'), 4);
        if slResolutions.IndexOf(sResolution) = -1 then slResolutions.Add(sResolution);
    end
    else sResolution := '2048';
    frm := TForm.Create(nil);
    try
        frm.Caption := 'Vault-Tec Enhanced FaceGen System';
        frm.Width := 600;
        frm.Height := 480;
        frm.Position := poMainFormCenter;
        frm.BorderStyle := bsDialog;
        frm.KeyPreview := True;
        frm.OnClose := frmOptionsFormClose;
        frm.OnKeyDown := FormKeyDown;

        picVefs := TPicture.Create;
        picVefs.LoadFromFile(sPicVefs);

        fImage := TImage.Create(frm);
		fImage.Picture := picVefs;
		fImage.Parent := frm;
        fImage.Width := 576;
		fImage.Height := 203;
		fImage.Left := 6;
		fImage.Top := 12;
        fImage.Stretch := True;

        edPluginName := TEdit.Create(frm);
        edPluginName.Parent := frm;
        edPluginName.Name := 'edPluginName';
        edPluginName.Left := 104;
        edPluginName.Top := fImage.Top + fImage.Height + 20;
        edPluginName.Width := 180;
        edPluginName.Hint := 'Sets the output plugin name.';
        edPluginName.ShowHint := True;
        CreateLabel(frm, 16, edPluginName.Top + 4, 'Output Plugin:');

        gbMode := TGroupBox.Create(frm);
        gbMode.Parent := frm;
        gbMode.Top := edPluginName.Top + 30;
        gbMode.Width := frm.Width - 24;
        gbMode.Left := 6;
        gbMode.Caption := 'Mode';
        gbMode.Height := 54;

        rbFaceGenPreset := TRadioButton.Create(gbMode);
        rbFaceGenPreset.Name := 'rbFaceGenPreset';
        rbFaceGenPreset.Parent := gbMode;
        rbFaceGenPreset.Left := 16;
        rbFaceGenPreset.Top := 24;
        rbFaceGenPreset.Width := 100;
        rbFaceGenPreset.Caption := 'Quick Face Fix';
        rbFaceGenPreset.Hint := 'Copies only NPCs to patch for whom facegen is missing,'
             + #13#10 + 'which will otherwise produce a missing head,'
             + #13#10 + 'and sets the "Is CharGen Face Preset" flag.'
             + #13#10 + 'The game will generate the face, which may cause stutter.';
        rbFaceGenPreset.ShowHint := True;

        rbOnlyMissing := TRadioButton.Create(gbMode);
        rbOnlyMissing.Name := 'rbOnlyMissing';
        rbOnlyMissing.Parent := gbMode;
        rbOnlyMissing.Left := rbFaceGenPreset.Left + rbFaceGenPreset.Width + 20;
        rbOnlyMissing.Top := rbFaceGenPreset.Top;
        rbOnlyMissing.Width := 150;
        rbOnlyMissing.Caption := 'Generate Missing Faces';
        rbOnlyMissing.Hint := 'Copies only NPCs to patch for whom facegen is missing,'
             + #13#10 + 'which will otherwise produce a missing head.'
             + #13#10 + 'This will be used to generate FaceGen via the Creation Kit.';
        rbOnlyMissing.ShowHint := True;
        rbOnlyMissing.Checked := True;

        rbAll := TRadioButton.Create(gbMode);
        rbAll.Name := 'rbAll';
        rbAll.Parent := gbMode;
        rbAll.Left := rbOnlyMissing.Left + rbOnlyMissing.Width + 20;
        rbAll.Top := rbFaceGenPreset.Top;
        rbAll.Width := 150;
        rbAll.Hint := 'Copies all NPCs that use FaceGen to patch'
             + #13#10 + 'to allow regenerating all faces in the game.'
             + #13#10 + 'This will be used to generate FaceGen via the Creation Kit.';
        rbAll.Caption := 'Generate All Faces';
        rbAll.ShowHint := True;

        gbOptions := TGroupBox.Create(frm);
        gbOptions.Parent := frm;
        gbOptions.Top := gbMode.Top + gbMode.Height + 12;
        gbOptions.Width := frm.Width - 24;
        gbOptions.Left := 6;
        gbOptions.Caption := 'Options';
        gbOptions.Height := 54;

        chkElric := TCheckBox.Create(gbOptions);
        chkElric.Parent := gbOptions;
        chkElric.Left := 16;
        chkElric.Top := 25;
        chkElric.Width := 100;
        chkElric.Caption := 'Run Elric';

        cbResolution := TComboBox.Create(gbOptions);
        cbResolution.Parent := gbOptions;
        cbResolution.Left := rbOnlyMissing.Left + 60;
        cbResolution.Top := 24;
        cbResolution.Width := 50;
        cbResolution.Style := csDropDownList;
        cbResolution.Items.Assign(slResolutions);
        cbResolution.ItemIndex := slResolutions.IndexOf(sResolution);
        cbResolution.Hint := 'Sets the texture resolution.';
        cbResolution.ShowHint := True;
        CreateLabel(gbOptions, rbOnlyMissing.Left, cbResolution.Top + 3, 'Resolution');

        btnStart := TButton.Create(frm);
        btnStart.Parent := frm;
        btnStart.Caption := 'Start';
        btnStart.ModalResult := mrOk;
        btnStart.Top := gbOptions.Top + gbOptions.Height + 24;

        btnCancel := TButton.Create(frm);
        btnCancel.Parent := frm;
        btnCancel.Caption := 'Cancel';
        btnCancel.ModalResult := mrCancel;
        btnCancel.Top := btnStart.Top;

        btnRuleEditor := TButton.Create(frm);
        btnRuleEditor.Parent := frm;
        btnRuleEditor.Caption := 'Rules';
        btnRuleEditor.OnClick := RuleEditor;
        btnRuleEditor.Width := 100;
        btnRuleEditor.Left := 8;
        btnRuleEditor.Hint := 'Launches the Rule Editor.';
        btnRuleEditor.ShowHint := True;
        btnRuleEditor.Top := btnStart.Top;

        btnStart.Left := gbOptions.Width - btnStart.Width - btnCancel.Width - 16;
        btnCancel.Left := btnStart.Left + btnStart.Width + 8;

        pnl := TPanel.Create(frm);
        pnl.Parent := frm;
        pnl.Left := 6;
        pnl.Top := btnStart.Top - 12;
        pnl.Width := frm.Width - 24;
        pnl.Height := 2;

        frm.ActiveControl := btnStart;
        frm.ScaleBy(uiScale, 100);
        frm.Font.Size := 8;
        frm.Height := btnStart.Top + btnStart.Height + btnStart.Height + 25;

        chkElric.Checked := StrToBool(joConfig.S['RunElric']);

        if joConfig.Contains('PluginName') then edPluginName.Text := joConfig.S['PluginName']
        else edPluginName.Text := 'FaceGen Output';

        if frm.ShowModal <> mrOk then begin
            Result := False;
            Exit;
        end
        else Result := True;

        sRealPlugin := edPluginName.Text;
        bOnlyMissing := rbOnlyMissing.Checked;
        bQuickFaceFix := rbFaceGenPreset.Checked;
        bAll := rbAll.Checked;
        sResolution := slResolutions[cbResolution.ItemIndex];

        joConfig.S['PluginName'] := sRealPlugin;
        joConfig.S['Resolution'] := sResolution;
        joConfig.S['RunElric'] := chkElric.Checked;
        if bCKPEExists then ini.WriteString('FaceGen', 'uTintMaskResolution', sResolution + '				; Sets NxN resolution when exporting textures');
    finally
        frm.Free;
    end;
end;

function RuleEditor: Boolean;
var
    i: integer;
    mnRules: TPopupMenu;
    MenuItem: TMenuItem;
    frm: TForm;
begin
    frm := TForm.Create(nil);
    try
        frm.Caption := 'Rule Editor';
        frm.Width := 1000;
        frm.Height := 600;
        frm.Position := poMainFormCenter;
        frm.BorderStyle := bsSizeable;
        frm.KeyPreview := True;
        frm.OnClose := frmOptionsFormClose;
        frm.OnKeyDown := FormKeyDown;
        frm.OnResize := frmResize;

        lvRules := TListView.Create(frm);
        lvRules.Parent := frm;

        lvRules.Top := 24;
        lvRules.Width := frm.Width - 36;
        lvRules.Left := (frm.Width - lvRules.Width)/2;
        lvRules.Height := frm.Height - 120;
        lvRules.ReadOnly := True;
        lvRules.ViewStyle := vsReport;
        lvRules.RowSelect := True;
        lvRules.DoubleBuffered := True;
        lvRules.Columns.Add.Caption := 'NPC or Plugin';
        lvRules.Columns[0].Width := 450;
        lvRules.Columns.Add.Caption := 'Only NPCs Matching';
        lvRules.Columns[1].Width := 160;
        lvRules.Columns.Add.Caption := 'Game Generates Face';
        lvRules.Columns[2].Width := 160;
        lvRules.Columns.Add.Caption := 'Creation Kit Generates Face';
        lvRules.Columns[3].Width := 190;
        lvRules.OwnerData := True;
        lvRules.OnData := lvRulesData;
        lvRules.OnDblClick := lvRulesDblClick;
        lvRules.Items.Count := joRules.Count;
        CreateLabel(frm, 16, lvRules.Top - 20, 'Rules');

        mnRules := TPopupMenu.Create(frm);
        lvRules.PopupMenu := mnRules;
        MenuItem := TMenuItem.Create(mnRules);
        MenuItem.Caption := 'Add';
        MenuItem.OnClick := RulesMenuAddClick;
        mnRules.Items.Add(MenuItem);
        MenuItem := TMenuItem.Create(mnRules);
        MenuItem.Caption := 'Delete';
        MenuItem.OnClick := RulesMenuDeleteClick;
        mnRules.Items.Add(MenuItem);
        MenuItem := TMenuItem.Create(mnRules);
        MenuItem.Caption := 'Edit';
        MenuItem.OnClick := RulesMenuEditClick;
        mnRules.Items.Add(MenuItem);

        btnRuleOk := TButton.Create(frm);
        btnRuleOk.Parent := frm;
        btnRuleOk.Caption := 'OK';
        btnRuleOk.ModalResult := mrOk;
        btnRuleOk.Top := lvRules.Height + lvRules.Top + 8;

        btnRuleCancel := TButton.Create(frm);
        btnRuleCancel.Parent := frm;
        btnRuleCancel.Caption := 'Cancel';
        btnRuleCancel.ModalResult := mrCancel;
        btnRuleCancel.Top := btnRuleOk.Top;

        btnRuleOk.Left := (frm.Width - btnRuleOk.Width - btnRuleCancel.Width - 8)/2;
        btnRuleCancel.Left := btnRuleOk.Left + btnRuleOk.Width + 8;

        frm.ScaleBy(uiScale, 100);
        frm.Font.Size := 8;

        if frm.ShowModal <> mrOk then begin
            Result := False;
            Exit;
        end
        else Result := True;

    finally
        frm.Free;
    end;
end;

function EditRuleForm(var ruleType, key, ChargenPreset, FacegenMode: string; var Exclusive, bEdit: Boolean): Boolean;
var
    frmRule: TForm;
    pnl: TPanel;
    btnOk, btnCancel: TButton;
    chkExclusive: TCheckBox;
    cbChargenPreset, cbFacegenMode: TComboBox;
    idx: integer;
begin
  frmRule := TForm.Create(nil);
  try
    frmRule.Caption := 'Rule';
    frmRule.Width := 800;
    frmRule.Height := 220;
    frmRule.Position := poMainFormCenter;
    frmRule.BorderStyle := bsDialog;
    frmRule.KeyPreview := True;
    frmRule.OnKeyDown := FormKeyDown;
    frmRule.OnClose := frmRuleFormClose;

    cbNPCPlugin := TComboBox.Create(frmRule);
    cbNPCPlugin.Parent := frmRule;
    cbNPCPlugin.Name := 'cbNPCPlugin';
    cbNPCPlugin.Items.Assign(slNPCPlugin);
    cbNPCPlugin.Left := 16;
    cbNPCPlugin.Top := 12;
    cbNPCPlugin.Width := 80;
    cbNPCPlugin.OnChange := NPCPluginChange;
    cbNPCPlugin.Style := csDropDownList;

    cbkey := TComboBox.Create(frmRule);
    cbkey.Parent := frmRule;
    cbkey.Name := 'cbkey';
    cbkey.Left := 120;
    cbkey.Top := 12;
    cbkey.Width := frmRule.Width - 140;


    chkExclusive := TCheckBox.Create(frmRule);
    chkExclusive.Parent := frmRule;
    chkExclusive.Left := 16;
    chkExclusive.Top := cbkey.Top + (2*cbkey.Height);
    chkExclusive.Width := 150;
    chkExclusive.Caption := 'Only NPCs Matching';
    chkExclusive.Hint := 'If any rule sets Only NPCs Matching to true,'
        + #13#10 + 'then any NPC that does not match such a rule will.'
        + #13#10 + 'not be processed.';
    chkExclusive.ShowHint := True;

    cbChargenPreset := TComboBox.Create(frmRule);
    cbChargenPreset.Parent := frmRule;
    cbChargenPreset.Name := 'cbChargenPreset';
    cbChargenPreset.Items.Assign(slCharGenPreset);
    cbChargenPreset.Left := chkExclusive.Left + chkExclusive.Width + 134;
    cbChargenPreset.Top := chkExclusive.Top - 2;
    cbChargenPreset.Width := 80;
    cbChargenPreset.Style := csDropDownList;
    cbChargenPreset.Hint := 'Sets the Is CharGen Face Preset flag.'
        + #13#10 + 'If default, no change will be made.'
        + #13#10 + 'If never, any NPC flagged as such will be unflagged,'
        + #13#10 + 'allowing pregenerated facegen data to be used.'
        + #13#10 + 'If always, adds the flag if missing. This is useful'
        + #13#10 + 'when you either want to use the LooksMenu on an '
        + #13#10 + 'NPC, or if the generated facegen is buggy.';
    cbChargenPreset.ShowHint := True;
    CreateLabel(frmRule, chkExclusive.Left + chkExclusive.Width + 16, cbChargenPreset.Top + 4, 'Game Generates Face:');

    cbFacegenMode := TComboBox.Create(frmRule);
    cbFacegenMode.Parent := frmRule;
    cbFacegenMode.Name := 'cbFacegenMode';
    cbFacegenMode.Items.Assign(slFaceGenMode);
    cbFacegenMode.Left := cbChargenPreset.Left + cbChargenPreset.Width + 178;
    cbFacegenMode.Top := cbChargenPreset.Top;
    cbFacegenMode.Width := 120;
    cbFacegenMode.Style := csDropDownList;
    cbFacegenMode.Hint := 'VEFS will create facegen data with the Creation Kit.'
        + #13#10 + 'If default, no change will be made.'
        + #13#10 + 'If only missing, any NPC missing facegen data will be made.'
        + #13#10 + 'If always, facegen data will always be made.';
    cbFacegenMode.ShowHint := True;
    CreateLabel(frmRule, cbChargenPreset.Left + cbChargenPreset.Width + 30, cbFacegenMode.Top + 4, 'Creation Kit Generates Face:');

    btnOk := TButton.Create(frmRule);
    btnOk.Parent := frmRule;
    btnOk.Caption := 'OK';
    btnOk.ModalResult := mrOk;
    btnOk.Left := frmRule.Width - 176;
    btnOk.Top := cbFacegenMode.Top + (2*cbFacegenMode.Height);

    btnCancel := TButton.Create(frmRule);
    btnCancel.Parent := frmRule;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Left := btnOk.Left + btnOk.Width + 8;
    btnCancel.Top := btnOk.Top;

    pnl := TPanel.Create(frmRule);
    pnl.Parent := frmRule;
    pnl.Left := 8;
    pnl.Top := btnOk.Top - 12;
    pnl.Width := frmRule.Width - 20;
    pnl.Height := 2;

    frmRule.Height := btnOk.Top + (4*btnOk.Height);

    cbNPCPlugin.ItemIndex := slNPCPlugin.IndexOf(ruleType);
    if SameText(ruleType, 'NPC') then begin
        cbkey.Items.Assign(slNPCRecords);
        cbkey.ItemIndex := slNPCRecords.IndexOf(key);
    end
    else begin
        cbkey.Items.Assign(slPluginFiles);
        cbkey.ItemIndex := slPluginFiles.IndexOf(key);
    end;

    cbkey.Text := key;
    chkExclusive.Checked := Exclusive;
    cbChargenPreset.ItemIndex := slCharGenPreset.IndexOf(ChargenPreset);
    cbFacegenMode.ItemIndex := slFaceGenMode.IndexOf(FacegenMode);

    frmRule.ActiveControl := cbkey;
    frmRule.ScaleBy(uiScale, 100);
    frmRule.Font.Size := 8;
    cbkey.Enabled := bEdit;
    cbNPCPlugin.Enabled := bEdit;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if frmRule.ShowModal <> mrOk then Exit;
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ruleType := slNPCPlugin[cbNPCPlugin.ItemIndex];
    sLastRuleType := ruleType;

    if SameText(ruleType, 'NPC') then begin
        key := cbkey.Text;
    end
    else begin
        key := cbkey.Text;
    end;

    Exclusive := chkExclusive.Checked;
    ChargenPreset := slCharGenPreset[cbChargenPreset.ItemIndex];
    FacegenMode := slFaceGenMode[cbFacegenMode.ItemIndex];

    Result := True;
  finally
    frmRule.Free;
  end;
end;

procedure NPCPluginChange(Sender: TObject);
var
    ruleType: string;
begin
    ruleType := slNPCPlugin[cbNPCPlugin.ItemIndex];
    if SameText(ruleType, 'NPC') then begin
        cbkey.Items.Assign(slNPCRecords);
    end
    else begin
        cbkey.Items.Assign(slPluginFiles);
    end;
end;

procedure lvRulesData(Sender: TObject; Item: TListItem);
{
    Populate lvRules
}
var
    i: integer;
    key: string;
begin
    key := joRules.Names[Item.Index];
    Item.Caption := key;
    Item.SubItems.Add(joRules.O[key].S['Exclusive']);
    Item.SubItems.Add(joRules.O[key].S['CharGen Preset']);
    Item.SubItems.Add(joRules.O[key].S['FaceGen Mode']);
end;

procedure lvRulesDblClick(Sender: TObject);
{
    Double click to edit rule
}
begin
    RulesMenuEditClick(nil);
end;

procedure RulesMenuAddClick(Sender: TObject);
{
    Add rule
}
var
    idx: integer;
    key, ruleType, ChargenPreset, FacegenMode: string;
    Exclusive: Boolean;
begin
    key := '';
    ruleType := sLastRuleType;
    Exclusive := false;
    ChargenPreset := 'Default';
    FacegenMode := 'Default';

    if not EditRuleForm(ruleType, key, ChargenPreset, FacegenMode, Exclusive, true) then Exit;

    joRules.O[key].S['Type'] := ruleType;
    joRules.O[key].S['Exclusive'] := BoolToStr(Exclusive);
    joRules.O[key].S['CharGen Preset'] := ChargenPreset;
    joRules.O[key].S['FaceGen Mode'] := FacegenMode;

    joUserRules.O[key].Assign(joRules.O[key]);
    bUserRulesChanged := True;

    lvRules.Items.Count := joRules.Count;
    lvRules.Refresh;
end;

procedure RulesMenuEditClick(Sender: TObject);
{
    Edit rule
}
var
    idx: integer;
    key, ruleType, ChargenPreset, FacegenMode: string;
    Exclusive: Boolean;
begin
    if not Assigned(lvRules.Selected) then Exit;
    idx := lvRules.Selected.Index;

    key := joRules.Names[idx];
    ruleType := joRules.O[key].S['Type'];
    Exclusive := StrToBool(joRules.O[key].S['Exclusive']);
    ChargenPreset := joRules.O[key].S['CharGen Preset'];
    FacegenMode := joRules.O[key].S['FaceGen Mode'];

    if not EditRuleForm(ruleType, key, ChargenPreset, FacegenMode, Exclusive, false) then Exit;

    joRules.O[key].S['Type'] := ruleType;
    joRules.O[key].S['Exclusive'] := BoolToStr(Exclusive);
    joRules.O[key].S['CharGen Preset'] := ChargenPreset;
    joRules.O[key].S['FaceGen Mode'] := FacegenMode;

    joUserRules.O[key].Assign(joRules.O[key]);
    bUserRulesChanged := True;

    lvRules.Items.Count := joRules.Count;
    lvRules.Refresh;
end;

procedure RulesMenuDeleteClick(Sender: TObject);
{
    Delete rule
}
var
    idx, uidx: integer;
    key: string;
begin
    if not Assigned(lvRules.Selected) then Exit;
    idx := lvRules.Selected.Index;
    key := joRules.Names[idx];
    joRules.Delete(idx);
    uidx := joUserRules.IndexOf(key);
    if uidx > -1 then begin
        joUserRules.Delete(uidx);
        bUserRulesChanged := True;
    end;
    lvRules.Items.Count := joRules.Count;
    lvRules.Refresh;
end;

procedure frmRuleFormClose(Sender: TObject; var Action: TCloseAction);
{
    Close rule edit menu handler.
}
begin
    if TForm(Sender).ModalResult <> mrOk then Exit;
    if cbkey.Text = '' then begin
        MessageDlg('ID must not be empty.', mtInformation, [mbOk], 0);
        Action := caNone;
    end;
end;

procedure frmResize(Sender: TObject);
{
    Handle resizing of elements in the rule menu.
}
var
    frm: TForm;
begin
    try
        frm := TForm(Sender);
        lvRules.Width := frm.Width - 36;
        lvRules.Left := (frm.Width - lvRules.Width)/2;
        lvRules.Height := frm.Height - btnRuleOk.Height - btnRuleOk.Height - btnRuleOk.Height - btnRuleOk.Height;

        btnRuleOk.Top := lvRules.Height + lvRules.Top + 8;
        btnRuleCancel.Top := btnRuleOk.Top;
        btnRuleOk.Left := (frm.Width - btnRuleOk.Width - btnRuleCancel.Width - 8)/2;
        btnRuleCancel.Left := btnRuleOk.Left + btnRuleOk.Width + 8;
    except
        frm := TForm(Sender);
    end;
end;

procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
{
    Cancel if Escape key is pressed.
}
begin
    if Key = VK_ESCAPE then TForm(Sender).ModalResult := mrCancel;
end;

procedure frmOptionsFormClose(Sender: TObject; var Action: TCloseAction);
{
    Close form handler.
}
begin
    if TForm(Sender).ModalResult <> mrOk then Exit
    else bSaveUserRules := True;
end;

function CreateLabel(aParent: TControl; x, y: Integer; aCaption: string): TLabel;
{
    Create a label.
}
begin
    Result := TLabel.Create(aParent);
    Result.Parent := aParent;
    Result.Left := x;
    Result.Top := y;
    Result.Caption := aCaption;
end;

// ----------------------------------------------------
// Utility Functions and Procedures go below.
// ----------------------------------------------------

function RequirementsCheck: Boolean;
{
    Check for required files.
}
begin
    //Check for Creation Kit
    if not FileExists(GamePath() + 'CreationKit.exe') then begin
        MessageDlg('Please install the Creation Kit before continuing.', mtError, [mbOk], 0);
        Result := False;
        Exit;
    end;

    //Check for Creation Kit Platform Extended
    if FileExists(GamePath() + 'CreationKitPlatformExtended.ini') then begin
        sCKFixesINI := GamePath() + 'CreationKitPlatformExtended.ini';
    end
    else begin
        MessageDlg('Please install Creation Kit Platform Extended by perchik71 before continuing.', mtError, [mbOk], 0);
        Result := False;
        Exit;
    end;

    Result := True;
end;

function CheckLaunchArguments: Boolean;
var
    i: integer;
    launchOption: string;
begin
    Result := False;
    if paramcount > 0 then begin
        for i:=1 to paramcount do begin
            launchOption := LowerCase(paramstr(i));
            AddMessage('Option: ' + launchOption);
            if Pos('-bbatchmode', launchOption) > 0 then begin
                Result := True;
                continue;
            end;
            if Pos('-vefsdir:', launchOption) > 0 then begin
                sVEFSDir := TrimRightChars(launchOption, 9);
                AddMessage('VEFS Dir: ' + sVEFSDir);
                sPicVefs := sVEFSDir + '\Images\vefs.png';
                joConfig.LoadFromFile(sVEFSDir + '\config.json');
                continue;
            end;
            if Pos('-bOnlyMissing:', launchOption) > 0 then begin
                bAll := False;
                bOnlyMissing := True;
                bQuickFaceFix := False;
                continue;
            end;
            if Pos('-bQuickFaceFix:', launchOption) > 0 then begin
                bAll := False;
                bOnlyMissing := False;
                bQuickFaceFix := True;
                continue;
            end;
            if Pos('-bAll:', launchOption) > 0 then begin
                bAll := True;
                bOnlyMissing := False;
                bQuickFaceFix := False;
                continue;
            end;
        end;
    end;
end;

procedure FetchRules;
{
    Loads the Rule JSON files.
}
var
    c, i: integer;
    f, j, key: string;
begin
    for i := 0 to Pred(FileCount) do begin
        f := GetFileName(FileByIndex(i));
        LoadRules(f);
    end;
    j := sVEFSDir + '\Rules\UserRules.json';
    if FileExists(j) then begin
        AddMessage('Loaded Rule File: ' + j);
        joUserRules := TJsonObject.Create;
        joUserRules.LoadFromFile(j);
        for c := 0 to Pred(joUserRules.Count) do begin
            key := joUserRules.Names[c];
            joRules.O[key].Assign(joUserRules.O[key]);
        end;
    end;
    SortJSONObjectKeys(joRules);
end;

procedure GetRules;
{
    Get NPC rules
}
var
    c, i: integer;
    key, ruleType: string;
    Exclusive, PresetAdd, PresetRemove, MissingOnly, Everything: boolean;
begin
    for i := 0 to Pred(joRules.Count) do begin
        key := joRules.Names[i];

        //Exclusive
        Exclusive := StrToBool(joRules.O[key].S['Exclusive']);
        if Exclusive then begin
            ruleType := joRules.O[key].S['Type'];
            if ruleType = 'NPC' then slNPCMatches.Add(key)
            else begin
                for c := 0 to Pred(joFaces.O[key].A['npcs'].Count) do slNPCMatches.Add(joFaces.O[key].A['npcs'].S[c]);
            end;
        end;

        //joRules.O[key].S['CharGen Preset'] := ChargenPreset;
        //joRules.O[key].S['FaceGen Mode'] := FacegenMode;

        //Preset Add
        PresetAdd := SameText(joRules.O[key].S['CharGen Preset'], 'Always');
        if PresetAdd then begin
            ruleType := joRules.O[key].S['Type'];
            if ruleType = 'NPC' then slPresetAdd.Add(key)
            else begin
                for c := 0 to Pred(joFaces.O[key].A['npcs'].Count) do slPresetAdd.Add(joFaces.O[key].A['npcs'].S[c]);
            end;
        end;

        //Preset Remove
        PresetRemove := SameText(joRules.O[key].S['CharGen Preset'], 'Never');
        if PresetRemove then begin
            ruleType := joRules.O[key].S['Type'];
            if ruleType = 'NPC' then slPresetRemove.Add(key)
            else begin
                for c := 0 to Pred(joFaces.O[key].A['npcs'].Count) do slPresetRemove.Add(joFaces.O[key].A['npcs'].S[c]);
            end;
        end;

        //Missing Only
        MissingOnly := SameText(joRules.O[key].S['FaceGen Mode'], 'Only If Missing');
        if MissingOnly then begin
            ruleType := joRules.O[key].S['Type'];
            if ruleType = 'NPC' then slMissingOnly.Add(key)
            else begin
                for c := 0 to Pred(joFaces.O[key].A['npcs'].Count) do slMissingOnly.Add(joFaces.O[key].A['npcs'].S[c]);
            end;
        end;

        //Everything
        Everything := SameText(joRules.O[key].S['FaceGen Mode'], 'Always');
        if Everything then begin
            ruleType := joRules.O[key].S['Type'];
            if ruleType = 'NPC' then slEverything.Add(key)
            else begin
                for c := 0 to Pred(joFaces.O[key].A['npcs'].Count) do slEverything.Add(joFaces.O[key].A['npcs'].S[c]);
            end;
        end;
    end;
end;

procedure LoadRules(f: string);
{
    Load LOD Rules and Material Swap Map JSON files
}
var
    sub: TJsonObject;
    c, a: integer;
    j, key: string;
    bFirstRuleJson: Boolean;
begin
    //VEFS directory Rules
    j := sVEFSDir + '\Rules\' + TrimLeftChars(f, 4) + '.json';
    if FileExists(j) then begin
        AddMessage('Loaded Rule File: ' + j);
        if bFirstRuleJson then begin
            bFirstRuleJson := False;
            joRules.LoadFromFile(j);
        end
        else begin
            sub := TJsonObject.Create;
            sub.LoadFromFile(j);
            for c := 0 to Pred(sub.Count) do begin
                key := sub.Names[c];
                joRules.O[key].Assign(sub.O[key]);
            end;
            sub.Free;
        end;
    end;

    //Data directory Rules
    j := 'VEFS\' + TrimLeftChars(f, 4) + '.json';
    if ResourceExists(j) then begin
        AddMessage('Loaded Rule File: ' + j);
        if bFirstRuleJson then begin
            bFirstRuleJson := False;
            joRules.LoadFromResource(j);
        end
        else begin
            sub := TJsonObject.Create;
            sub.LoadFromResource(j);
            for c := 0 to Pred(sub.Count) do begin
                key := sub.Names[c];
                joRules.O[key].Assign(sub.O[key]);
            end;
            sub.Free;
        end;
    end;
end;

// ----------------------------------------------------
// Record processing Functions and Procedures go below.
// ----------------------------------------------------

procedure CollectAssets;
var
    slArchivesToAdd, slArchivedFiles: TStringList;
    slContainers: TwbFastStringList;
    i, j, idx: integer;
    f, archive, masterFile: string;
begin
    slContainers := TwbFastStringList.Create;
    slArchivesToAdd := TStringList.Create;

    ResourceContainerList(slContainers);

    for i := 0 to Pred(slContainers.Count) do begin
        archive := TrimRightChars(slContainers[i], Length(wbDataPath));
        if ContainsText(archive, ' - Animations.ba2') then continue;
        if ContainsText(archive, ' - Interface.ba2') then continue;
        if ContainsText(archive, ' - MeshesExtra.ba2') then continue;
        if ContainsText(archive, ' - Nvflex.ba2') then continue;
        if ContainsText(archive, ' - Shaders.ba2') then continue;
        if ContainsText(archive, ' - Sounds.ba2') then continue;
        if ContainsText(archive, ' - Startup.ba2') then continue;
        if ContainsText(archive, ' - Textures1.ba2') then continue;
        if ContainsText(archive, ' - Textures2.ba2') then continue;
        if ContainsText(archive, ' - Textures3.ba2') then continue;
        if ContainsText(archive, ' - Textures4.ba2') then continue;
        if ContainsText(archive, ' - Textures5.ba2') then continue;
        if ContainsText(archive, ' - Textures6.ba2') then continue;
        if ContainsText(archive, ' - Textures7.ba2') then continue;
        if ContainsText(archive, ' - Textures8.ba2') then continue;
        if ContainsText(archive, ' - Textures9.ba2') then continue;
        if ContainsText(archive, ' - Voices.ba2') then continue;
        if ContainsText(archive, ' - Voices_cn.ba2') then continue;
        if ContainsText(archive, ' - Voices_de.ba2') then continue;
        if ContainsText(archive, ' - Voices_en.ba2') then continue;
        if ContainsText(archive, ' - Voices_es.ba2') then continue;
        if ContainsText(archive, ' - Voices_esmx.ba2') then continue;
        if ContainsText(archive, ' - Voices_fr.ba2') then continue;
        if ContainsText(archive, ' - Voices_it.ba2') then continue;
        if ContainsText(archive, ' - Voices_ja.ba2') then continue;
        if ContainsText(archive, ' - Voices_pl.ba2') then continue;
        if ContainsText(archive, ' - Voices_ptbr.ba2') then continue;
        if ContainsText(archive, ' - Voices_ru.ba2') then continue;
        if archive = '' then continue;
        if ContainsText(archive, ' - Main.ba2') or ContainsText(archive, ' - Textures.ba2') then begin
            slArchivedFiles := TStringList.Create;
            ResourceList(slContainers[i], slArchivedFiles);
            for j := 0 to Pred(slArchivedFiles.Count) do begin
                f := LowerCase(slArchivedFiles[j]);
                idx := slAssets.IndexOf(f);
                if idx > -1 then begin
                    slArchivesToAdd.Add(archive);
                    masterFile := GetMasterFromArchive(archive);
                    if masterFile <> '' then begin
                        AddMasterIfMissing(iPluginFile, masterFile);
                        SortMasters(iPluginFile);
                    end;
                    break;
                end;
            end;

            slArchivedFiles.Free;
        end;
    end;


    slArchivesToAdd.Free;
    slContainers.Free;
end;

procedure CreateRealPlugin;
var
    i: integer;
    f: IInterface;
    filename: string;
begin
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        filename := GetFileName(f);
        if SameText(filename, sRealPlugin + '.esp') then begin
            iRealPlugin := f;
            //Clear out any previous edits to the file.
            if HasGroup(iRealPlugin, 'HDPT') then begin
                RemoveNode(GroupBySignature(iRealPlugin, 'HDPT'));
            end;
            if HasGroup(iRealPlugin, 'NPC_') then begin
                RemoveNode(GroupBySignature(iRealPlugin, 'NPC_'));
            end;
            CleanMasters(iRealPlugin);
            AddMasterIfMissing(iRealPlugin, 'Fallout4.esm');
        end;
    end;
    if not Assigned(iRealPlugin) then begin
        iRealPlugin := AddNewFileName(sRealPlugin + '.esp', True);
        AddMasterIfMissing(iRealPlugin, 'Fallout4.esm');
    end;
end;

procedure CollectRecords;
{
    Collects records.
}
var
    i, j, idx: integer;
    filename, recordId, sex: string;
    r, race: IInterface;
    g: IwbGroupRecord;
    isPlayerChild, MQ101PlayerSpouseMale: IwbMainRecord;
    f, fallout4esm: IwbFile;
    slRace, slNpc, slRaceSex: TStringList;
    bHadFaceGenNPC: Boolean;
begin
    slRace := TStringList.Create;
    slNpc := TStringList.Create;

    slRaceSex := TStringList.Create;
    slRaceSex.Sorted := True;
    slRaceSex.Duplicates := dupIgnore;

    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        filename := GetFileName(f);
        if SameText(filename, 'Fallout4.exe') then continue;

        if SameText(filename, 'Fallout4.esm') then begin
            fallout4esm := f;
            isPlayerChild := RecordByFormID(fallout4esm, $001916C4, False); //these are handled special for facegen
            MQ101PlayerSpouseMale := RecordByFormID(fallout4esm, $000A7D34, False); //handled special for facegen
        end
        else if SameText(filename, sPatchName) then begin
            iPluginFile := f;
            //Clear out any previous edits to the file.
            if HasGroup(iPluginFile, 'HDPT') then begin
                RemoveNode(GroupBySignature(iPluginFile, 'HDPT'));
            end;

            if HasGroup(iPluginFile, 'NPC_') then begin
                RemoveNode(GroupBySignature(iPluginFile, 'NPC_'));
            end;
            CleanMasters(iPluginFile);
            AddMasterIfMissing(iPluginFile, 'Fallout4.esm');
        end;
    end;

    if not Assigned(iPluginFile) then begin
        iPluginFile := AddNewFileName(sPatchName, True);
        AddMasterIfMissing(iPluginFile, 'Fallout4.esm');
    end;

    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        filename := GetFileName(f);
        if SameText(filename, 'Fallout4.exe') then continue;

        //RACE
        g := GroupBySignature(f, 'RACE');
        for j := 0 to Pred(ElementCount(g)) do begin
            r := WinningOverride(ElementByIndex(g, j));
            recordId := GetFileName(r) + #9 + ShortName(r);
            idx := slRace.IndexOf(recordId);
            if idx > -1 then continue;
            if GetElementEditValues(r, 'DATA\Flags\FaceGen Head') <> '1' then continue;
            slRace.Add(recordId);
            tlRace.Add(r);
        end;

        //NPC_
        g := GroupBySignature(f, 'NPC_');
        bHadFaceGenNPC := false;
        for j := 0 to Pred(ElementCount(g)) do begin
            r := WinningOverride(ElementByIndex(g, j));
            recordId := GetFileName(r) + #9 + ShortName(r);
            idx := slNpc.IndexOf(recordId);
            if idx > -1 then begin
                bHadFaceGenNPC := true;
                joFaces.O[filename].A['npcs'].Add(NPC_id(r));
                continue;
            end;
            race := WinningOverride(LinksTo(ElementByPath(r, 'RNAM')));
            idx := tlRace.IndexOf(race);
            if idx = -1 then continue;
            if GetElementEditValues(r, 'ACBS\Use Template Actors\Traits') = '1' then continue;
            if KeywordExists(r, isPlayerChild) then continue;
            if GetLoadOrderFormID(r) = GetLoadOrderFormID(MQ101PlayerSpouseMale) then continue;
            slNpc.Add(recordId);
            slNPCRecords.Add(NPC_id(r));
            tlNpc.Add(r);
            joFaces.O[filename].A['npcs'].Add(NPC_id(r));
            bHadFaceGenNPC := true;
            sex := 'Male';
            if GetElementEditValues(r, 'ACBS\Flags\Female') = '1' then sex := 'Female';
            slRaceSex.Add(ShortName(race) + #9 + sex + #9 + ShortName(r));
            joFaces.O['races'].O[ShortName(race)].S[sex] := true;
            joFaces.O['races'].O[ShortName(race)].A[sex + '_NPCs'].Add(ShortName(r));
        end;
        if bHadFaceGenNPC then slPluginFiles.Add(filename);
    end;
    ListStringsInStringList(slRaceSex);

    slRace.Free;
    slNpc.Free;
    slRaceSex.Free;
end;

procedure ProcessHeadParts;
{
    Process Head Parts
}
var
    i, j, k, editorInc, idx: integer;
    editorId, material, model, newEditorId, recordId, tri: string;
    g: IwbGroupRecord;
    f: IwbFile;
    e, r, eMaterials, eParts, headpart: IInterface;
    slHdpt, slEditorIds: TStringList;
begin
    slHdpt := TStringList.Create;
    slEditorIds := TStringList.Create;

    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        g := GroupBySignature(f, 'HDPT');
        for j := 0 to Pred(ElementCount(g)) do begin
            r := WinningOverride(ElementByIndex(g, j));
            recordId := GetFileName(r) + #9 + ShortName(r);
            idx := slHdpt.IndexOf(recordId);
            if idx > -1 then continue;
            if ElementExists(r, 'Model\MODL') then begin
                model := wbNormalizeResourceName(GetElementEditValues(r, 'Model\MODL'), resMesh);
                slModels.Add(model);
                slAssets.Add(model);
            end;
            if ElementExists(r, 'Model\MODT') then begin
                eMaterials := ElementByPath(r, 'Model\MODT\Materials');
                for k := 0 to Pred(ElementCount(eMaterials)) do begin
                    e := ElementByIndex(eMaterials, k);
                    material := wbNormalizeResourceName(GetSummary(e), resMaterial);
                    slMaterials.Add(material);
                    slAssets.Add(material);
                end;
            end;
            if ElementExists(r, 'Parts') then begin
                eParts := ElementByPath(r, 'Parts');
                for k := 0 to Pred(ElementCount(eParts)) do begin
                    e := ElementbyIndex(eParts, k);
                    tri := wbNormalizeResourceName(GetElementEditValues(e, 'NAM1'), resMesh);
                    slModels.Add(tri);
                    slAssets.Add(tri);
                end;
            end;
            slHdpt.Add(recordId);
            tlHdpt.Add(r);
            editorId := GetElementEditValues(r, 'EDID');
            newEditorId := StringReplace(editorId, ' ', '', [rfReplaceAll, rfIgnoreCase]);
            newEditorId := StringReplace(newEditorId, '+', '', [rfReplaceAll, rfIgnoreCase]);
            newEditorId := StringReplace(newEditorId, '=', '', [rfReplaceAll, rfIgnoreCase]);
            editorInc := 0;
            idx := slEditorIds.IndexOf(newEditorId);
            while idx <> -1 do begin
                editorInc := editorInc + 1;
                newEditorId := newEditorId + 'fix' + IntToStr(editorInc);
                idx := slEditorIds.IndexOf(newEditorId);
            end;
            slEditorIds.Add(newEditorId);
            if SameText(editorId, newEditorId) then continue;
            AddRequiredElementMasters(r, iPluginFile, False, True);
            SortMasters(iPluginFile);
            headpart := wbCopyElementToFile(r, iPluginFile, False, True);
            bNeedPlugin := true;
            SetElementEditValues(headpart, 'EDID', newEditorId);
            tlCopyToReal.Add(headpart);
        end;
    end;
    slEditorIds.Free;
    slHdpt.Free;
end;

procedure ProcessRecords;
{
    Process Records.
}
var
    i, count: integer;
    slNpc: TStringList;
begin
    ProcessHeadParts;

    slNpc := TStringList.Create;
    for i := 0 to Pred(tlRace.Count) do begin
        ProcessRace(ObjectToElement(tlRace[i]));
    end;

    GetRules;

    count := 0;
    for i := 0 to Pred(tlNpc.Count) do begin
        ProcessNPC(ObjectToElement(tlNpc[i]), slNpc, count);
    end;
    ListStringsInStringList(slNPC);
    joConfig.S['Face_Count'] := count;
    slNpc.Free;

    if bQuickFaceFix then Exit;
    for i := 0 to Pred(tlCopyToReal.Count) do begin
        CopyToRealPlugin(ObjectToElement(tlCopyToReal[i]));
    end;
end;

procedure ProcessNPC(r: IInterface; var slNPC: TStringList; var count: integer);
{
    Process NPC
}
var
    masterFile, relativeFormid, sn: string;
    npc, masterRecord, npcnew: IInterface;
    bRemovePreset, bAddPreset, bMissingHere, bAllHere, bWasChargenFacePreset: Boolean;
    idx: integer;
begin
    bRemovePreset := false;
    bAddPreset := false;
    bMissingHere := false;
    bAllHere := false;

    sn := NPC_id(r);

    //If any rule sets "Only NPCs Matching" then those NPCs are added to slNPCMatches. Skip this NPC if not in that list.
    if ((slNPCMatches.Count > 0) and (slNPCMatches.IndexOf(sn) = -1)) then begin
        AddMessage('Skipped ' + sn + ' because it was not in the list of matching NPCs.');
        Exit;
    end;

    idx := slPresetRemove.IndexOf(sn);
    if idx > -1 then bRemovePreset := true;

    if (GetElementEditValues(r, 'ACBS\Flags\Is CharGen Face Preset') = '1') then begin
        bWasChargenFacePreset := true;
        if not bRemovePreset then Exit;
    end
    else bWasChargenFacePreset := false;

    masterRecord := MasterOrSelf(r);
    masterFile := GetFileName(masterRecord);

    idx := slPresetAdd.IndexOf(sn);
    if idx > -1 then bAddPreset := true;

    idx := slMissingOnly.IndexOf(sn);
    if idx > -1 then bMissingHere := true;

    idx := slEverything.IndexOf(sn);
    if idx > -1 then bAllHere := true;

    if bMissingHere or bOnlyMissing or bQuickFaceFix then begin
        relativeFormid := '00' + TrimRightChars(IntToHex(FixedFormID(r), 8), 2);
        if not bAllHere then begin
            if not bAddPreset then begin
                if FaceGenExists(relativeFormid, masterFile) then Exit;
            end;
        end;
    end;


    AddRequiredElementMasters(r, iPluginFile, False, True);
    SortMasters(iPluginFile);
    npc := wbCopyElementToFile(r, iPluginFile, False, True);
    bNeedPlugin := true;
    slNpc.Add(ShortName(r));
    count := count + 1;

    if bRemovePreset then begin
        SetElementEditValues(npc, 'ACBS\Flags\Is CharGen Face Preset', '0');
        if bWasChargenFacePreset then CopyToRealPlugin(npc);
    end;

    if (not bRemovePreset) and (bAddPreset) then begin
        SetElementEditValues(npc, 'ACBS\Flags\Is CharGen Face Preset', '1');
        count := count - 1;
        if not bWasChargenFacePreset then CopyToRealPlugin(npc);
    end;

    if not bRemovePreset and bQuickFaceFix then begin
        SetElementEditValues(npc, 'ACBS\Flags\Is CharGen Face Preset', '1');
        count := 0;
    end;

    if bQuickFaceFix then Exit;
    Remove(ElementByName(npc, 'Items'));

end;

procedure ProcessRace(race: IInterface);
{
    Process race
}
var
    i, k, l, m, textureCount: integer;
    r, e, eTints, eTintGroup, eOptions, eOption, eTextures, eHeadParts, eHeadPart, eHead, eFaceDetails, eFace, eTxst: IInterface;
    bTint: Boolean;
    recordId, recordIdHere, material, texture: string;
    slTxst: TStringList;
    tlTxst: TList;
begin
    slTxst := TStringList.Create;
    tlTxst := TList.Create;
    ////////////////////////////////////////////////////////////////////
    //Race
    r := race;
    recordId := GetFileName(r) + #9 + ShortName(r);
    AddMessage('---------------------------------------------------------------------------------------');
    AddMessage(recordId);

    if StrToBool(joFaces.O['races'].O[ShortName(r)].S['Male']) then begin
        //Male Head Parts (sorted)
        //  Head Part
        //    HEAD > Links To HDPT record
        // if ElementExists(r, 'Male Head Parts') then begin
        //     eHeadParts := ElementByPath(r, 'Male Head Parts');
        //     for k := 0 to Pred(ElementCount(eHeadParts)) do begin
        //         eHeadPart := ElementByIndex(eHeadParts, k);
        //         eHead := WinningOverride(LinksTo(ElementByIndex(eHeadPart, 1)));
        //         recordIdHere := GetFileName(eHead) + #9 + ShortName(eHead);
        //         AddMessage(recordIdHere);
        //     end;
        // end;

        //Male Race Presets
        //  RPRM - Preset NPC#0 > Links to NPC_ preset

        //Male Face Details (sorted)
        //  FTSM - Texture Set > Links to TXST facegen head textures
        if ElementExists(r, 'Male Face Details') then begin
            eFaceDetails := ElementByPath(r, 'Male Face Details');
            for k := 0 to Pred(ElementCount(eFaceDetails)) do begin
                eTxst := WinningOverride(LinksTo(ElementByIndex(eFaceDetails, k)));
                recordIdHere := GetFileName(eTxst) + #9 + ShortName(eTxst);
                if slTxst.IndexOf(recordIdHere) <> -1 then continue;
                slTxst.Add(recordIdHere);
                tlTxst.Add(eTxst);
            end;
        end;


        //DFTM - Male Default Face Texture > Links to TXST facegen head default texture
        if ElementExists(r, 'DFTM') then begin
            eTxst := WinningOverride(LinksTo(ElementByPath(r, 'DFTM')));
            recordIdHere := GetFileName(eTxst) + #9 + ShortName(eTxst);
            if slTxst.IndexOf(recordIdHere) = -1 then begin
                slTxst.Add(recordIdHere);
                tlTxst.Add(eTxst);
            end;
        end;


        //Male Tints
        if ElementExists(r, 'Male Tint Layers') then begin
            eTints := ElementByPath(r, 'Male Tint Layers');
            for k := 0 to Pred(ElementCount(eTints)) do begin
                //Group # 0
                eTintGroup := ElementByIndex(eTints, k);
                //  Options
                eOptions := ElementByName(eTintGroup, 'Options');
                for l := 0 to Pred(ElementCount(eOptions)) do begin
                    //Option #0
                    eOption := ElementByIndex(eOptions, l);
                    //  Textures
                    eTextures := ElementByName(eOption, 'Textures');
                    textureCount := ElementCount(eTextures);
                    if textureCount = 1 then bTint := 1 else bTint := 0;
                    for m := 0 to Pred(textureCount) do begin
                        //TIET - Texture #0
                        e := ElementByIndex(eTextures, m);
                        texture := GetEditValue(e);
                        if bTint then AddTexture(recordId, texture, 'tint')
                        else if m = 0 then AddTexture(recordId, texture, 'diffuse')
                        else if m = 1 then AddTexture(recordId, texture, 'normal')
                        else if m = 2 then AddTexture(recordId, texture, 'specular');
                    end;
                end;
            end;
        end;

    end;

    if StrToBool(joFaces.O['races'].O[ShortName(r)].S['Female']) then begin

        //Female Head Parts (sorted)
        //  Head Part
        //    HEAD > Links To HDPT record

        //Female Race Presets
        //  RPRF - Preset NPC#0 > Links to NPC_ preset

        //Female Face Details (sorted)
        //  FTSF - Texture Set > Links to TXST facegen head textures
        if ElementExists(r, 'Female Face Details') then begin
            eFaceDetails := ElementByPath(r, 'Female Face Details');
            for k := 0 to Pred(ElementCount(eFaceDetails)) do begin
                eTxst := WinningOverride(LinksTo(ElementByIndex(eFaceDetails, k)));
                recordIdHere := GetFileName(eTxst) + #9 + ShortName(eTxst);
                if slTxst.IndexOf(recordIdHere) <> -1 then continue;
                slTxst.Add(recordIdHere);
                tlTxst.Add(eTxst);
            end;
        end;

        //DFTF - Female Default Face Texture > Links to TXST facegen head default texture
        if ElementExists(r, 'DFTF') then begin
            eTxst := WinningOverride(LinksTo(ElementByPath(r, 'DFTF')));
            recordIdHere := GetFileName(eTxst) + #9 + ShortName(eTxst);
            if slTxst.IndexOf(recordIdHere) = -1 then begin
                slTxst.Add(recordIdHere);
                tlTxst.Add(eTxst);
            end;
        end;

        //Female Tints
        if ElementExists(r, 'Female Tint Layers') then begin
            eTints := ElementByPath(r, 'Female Tint Layers');
            for k := 0 to Pred(ElementCount(eTints)) do begin
                //Group # 0
                eTintGroup := ElementByIndex(eTints, k);
                //  Options
                eOptions := ElementByName(eTintGroup, 'Options');
                for l := 0 to Pred(ElementCount(eOptions)) do begin
                    //Option #0
                    eOption := ElementByIndex(eOptions, l);
                    //  Textures
                    eTextures := ElementByName(eOption, 'Textures');
                    textureCount := ElementCount(eTextures);
                    if textureCount = 1 then bTint := 1 else bTint := 0;
                    for m := 0 to Pred(textureCount) do begin
                        //TIET - Texture #0
                        e := ElementByIndex(eTextures, m);
                        texture := GetEditValue(e);
                        if bTint then AddTexture(recordId, texture, 'tint')
                        else if m = 0 then AddTexture(recordId, texture, 'diffuse')
                        else if m = 1 then AddTexture(recordId, texture, 'normal')
                        else if m = 2 then AddTexture(recordId, texture, 'specular');
                    end;
                end;
            end;
        end;

    end;
    ////////////////////////////////////////////////////////////////////
    //Txst
    for i := 0 to Pred(tlTxst.Count) do begin
        r := ObjectToElement(tlTxst[i]);
        recordId := GetFileName(r) + #9 + ShortName(r);

        if GetElementEditValues(r, 'DNAM - Flags\Facegen Textures') <> '1' then continue;

        if ElementExists(r, 'Textures (RGB/A)\TX00') then begin
            AddTexture(recordId, GetElementEditValues(r, 'Textures (RGB/A)\TX00'), 'diffuse');
        end;
        if ElementExists(r, 'Textures (RGB/A)\TX01') then begin
            AddTexture(recordId, GetElementEditValues(r, 'Textures (RGB/A)\TX01'), 'normal');
        end;
        if ElementExists(r, 'Textures (RGB/A)\TX07') then begin
            AddTexture(recordId, GetElementEditValues(r, 'Textures (RGB/A)\TX07'), 'specular');
        end;

        if ElementExists(r, 'MNAM') then begin
            material := wbNormalizeResourceName(GetElementEditValues(r, 'MNAM'), resMaterial);
            slMaterials.Add(material);
            slAssets.Add(material);
            AddMaterialTextures(material);
        end;
    end;

    TextureInfo;


    slTxst.Free;
    tlTxst.Free;
    slDiffuseTextures.Free;
    slNormalTextures.Free;
    slSpecularTextures.Free;

    slDiffuseTextures := TStringList.Create;
    slDiffuseTextures.Sorted := True;
    slDiffuseTextures.Duplicates := dupIgnore;

    slNormalTextures := TStringList.Create;
    slNormalTextures.Sorted := True;
    slNormalTextures.Duplicates := dupIgnore;

    slSpecularTextures := TStringList.Create;
    slSpecularTextures.Sorted := True;
    slSpecularTextures.Duplicates := dupIgnore;

end;

procedure TextureInfo;
var
    i: integer;
    f: string;
begin
    AddMessage('=======================================================================================');
    AddMessage('Diffuse textures:');
    for i := 0 to Pred(slDiffuseTextures.Count) do begin
        f := slDiffuseTextures[i];
        if f = '' then continue;
        AddMessage(f + #9 + GetTextureInfo(f));
    end;
    AddMessage('=======================================================================================');
    AddMessage('Normal textures:');
    for i := 0 to Pred(slNormalTextures.Count) do begin
        f := slNormalTextures[i];
        if f = '' then continue;
        AddMessage(f + #9 + GetTextureInfo(f));
    end;
    AddMessage('=======================================================================================');
    AddMessage('Specular textures:');
    for i := 0 to Pred(slSpecularTextures.Count) do begin
        f := slSpecularTextures[i];
        if f = '' then continue;
        AddMessage(f + #9 + GetTextureInfo(f));
    end;
end;


// ----------------------------------------------------
// Generic Functions and Procedures go below.
// ----------------------------------------------------

function CopyToRealPlugin(r: IInterface): IInterface;
begin
    AddRequiredElementMasters(r, iRealPlugin, False, True);
    SortMasters(iRealPlugin);
    Result := wbCopyElementToFile(r, iRealPlugin, False, True);
end;

procedure AddTexture(id, texture, textureType: string);
{
    Add texture to texture string lists if present, and warn if missing for the id.
}
begin
    if SameText(texture, '') then Exit;
    texture := wbNormalizeResourceName(texture, resTexture);
    if not ResourceExists(texture) then begin
        AddMessage('Warning:' + id + ' defines missing texture ' + texture);
        Exit;
    end;
    slTextures.Add(texture);
    slAssets.Add(texture);

    if textureType = '' then begin
        if SameText(RightStr(texture, 6), '_d.dds') then slDiffuseTextures.add(texture)
        else if SameText(RightStr(texture, 6), '_n.dds') then slNormalTextures.add(texture)
        else if SameText(RightStr(texture, 6), '_s.dds') then slSpecularTextures.add(texture)
        else AddMessage('Texture type could not verified:' + #9 + texture);
    end
    else if textureType = 'tint' then begin
        slDiffuseTextures.Add(texture);
        slTintTextures.Add(texture);
    end
    else if textureType = 'diffuse' then slDiffuseTextures.Add(texture)
    else if textureType = 'normal' then slNormalTextures.Add(texture)
    else if textureType = 'specular' then slSpecularTextures.Add(texture);
end;

function GetTextureInfo(f: string): string;
{
    Get resolution of texture in h x w format
}
var
    dds: TwbDDSFile;
    height, width, mipmaps: integer;
    cubemap: string;
begin
    dds := TwbDDSFile.Create;
    try
        try
            dds.LoadFromResource(f);
            if dds.EditValues['Magic'] <> 'DDS ' then
                raise Exception.Create('Not a valid DDS file');
        except
            on E: Exception do begin
                AddMessage('Error reading: ' + f + ' <' + E.Message + '>');
            end;
        end;
        height := dds.NativeValues['HEADER\dwHeight'];
        width := dds.NativeValues['HEADER\dwWidth'];
        Result := IntToStr(height) + ' x ' + IntToStr(width);
    finally
        dds.Free;
    end;
end;

function GetMasterFromArchive(a: string): string;
{
    Find the plugin that is loading the archive.
}
var
    f, filename: string;
    i: integer;
begin
    Result := '';
    if ContainsText(a, ' - Main.ba2') then f := LowerCase(TrimLeftChars(a, Length(' - Main.ba2')))
    else if ContainsText(a, ' - Textures.ba2') then f := LowerCase(TrimLeftChars(a, Length(' - Textures.ba2')));

    for i := 0 to Pred(FileCount) do begin
        filename := GetFileName(FileByIndex(i));
        if LowerCase(TrimLeftChars(filename, 4)) = f then begin
            Result := filename;
            break;
        end;
    end;
end;

procedure AddMaterialTextures(f: string);
{
    Add textures from material.
}
var
    i: integer;
    tp, texture: string;
    bgsm: TwbBGSMFile;
    bgem: TwbBGEMFile;
    el: TdfElement;
begin
    if RightStr(f, 4) = 'bgsm' then begin
        bgsm := TwbBGSMFile.Create;
        try
            bgsm.LoadFromResource(f);
            el := bgsm.Elements['Textures'];
            for i := 0 to 2 do begin
                tp := el[i].EditValue;
                if Length(tp) < 4 then continue;
                if i = 0 then AddTexture(f, tp, 'diffuse')
                else if i = 1 then AddTexture(f, tp, 'normal')
                else if i = 2 then AddTexture(f, tp, 'specular');
            end;
        finally
            bgsm.Free;
        end;
    end
    else if RightStr(f, 4) = 'bgem' then begin
        AddMessage('Skipping BGEM material: ' + f);
        // bgem := TwbBGEMFile.Create;
        // try
        //     bgem.LoadFromResource(f);

        //     el := bgem.Elements['Base Texture'];
        //     AddTexture(f, el);

        //     el := bgem.Elements['Normal Texture'];
        //     AddTexture(f, el);

        //     el := bgem.Elements['Envmap Mask Texture'];
        //     AddTexture(f, el);
        // finally
        //     bgem.Free;
        // end;
    end;
end;

function KeywordExists(r: IInterface; keyword: IwbMainRecord): boolean;
{
    Checks if the r has keyword.
}
var
    i: integer;
    keywords: IInterface;
begin
    Result := False;
    keywords := ElementByPath(r, 'KWDA');
    for i := 0 to Pred(ElementCount(keywords)) do begin
        if GetLoadOrderFormID(LinksTo(ElementByIndex(keywords, i))) = GetLoadOrderFormID(keyword) then begin
            Result := True;
            break;
        end;
    end;
end;

function FaceGenExists(relativeFormid, masterFile: string): Boolean;
begin
    Result := False;
    if not ResourceExists('Meshes\Actors\Character\FaceGenData\FaceGeom\' + masterFile + '\' + relativeFormid + '.nif') then Exit;
    if not ResourceExists('Textures\Actors\Character\FaceCustomization\' + masterFile + '\' + relativeFormid + '_d.dds') then Exit;
    if not ResourceExists('Textures\Actors\Character\FaceCustomization\' + masterFile + '\' + relativeFormid + '_msn.dds') then Exit;
    if not ResourceExists('Textures\Actors\Character\FaceCustomization\' + masterFile + '\' + relativeFormid + '_s.dds') then Exit;
    Result := True;
end;

procedure SortJSONObjectKeys(JSONObj: TJsonObject);
{
    Sorts JSON keys alphabetically.
}
var
    SortedKeys: TStringList;
    Key: string;
    NewJSONObj: TJsonObject;
    i: integer;
begin
    // Create a sorted list of keys
    SortedKeys := TStringList.Create;
    NewJSONObj := TJsonObject.Create;
    try
        for i := 0 to Pred(JSONObj.Count) do SortedKeys.Add(JSONObj.Names[i]);
        SortedKeys.Sort; // Sort the keys alphabetically

        for i := 0 to Pred(SortedKeys.Count) do begin
            Key := SortedKeys[i];
            NewJSONObj.O[Key].Assign(JSONObj.O[Key]);
        end;

        // Replace the original JSONObj with the sorted one
        JSONObj.Clear;
        JSONObj.Assign(NewJSONObj);
    finally
        SortedKeys.Free;
        NewJSONObj.Free;
    end;
end;

function GamePath: string;
begin
    Result := TrimLeftChars(wbDataPath, 5);
end;

function NPC_id(r: IInterface): string;
var
    relativeFormid, editorID, fullName, filename: string;
begin
    editorId := GetElementEditValues(r, 'EDID');
    if ElementExists(r, 'FULL') then
        fullName := GetElementEditValues(r, 'FULL') + '     '
    else fullName := '';
    filename := GetFileName(MasterOrSelf(r));
    relativeFormid := '00' + TrimRightChars(IntToHex(FixedFormID(r), 8), 2);
    Result := fullName + editorId + '     [ ' + filename + '\' + relativeFormid + ' ]';
end;

procedure ListStringsInStringList(sl: TStringList);
{
    Given a TStringList, add a message for all items in the list.
}
var
    i: integer;
begin
    AddMessage('=======================================================================================');
    for i := 0 to Pred(sl.Count) do AddMessage(sl[i]);
    AddMessage('=======================================================================================');
end;

function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

function TrimLeftChars(s: string; chars: integer): string;
{
    Returns left string - chars
}
begin
    Result := LeftStr(s, Length(s) - chars);
end;

function StrToBool(str: string): boolean;
{
    Given a string, return a boolean.
}
begin
    if (LowerCase(str) = 'true') or (str = '1') then Result := True else Result := False;
end;

function BoolToStr(b: boolean): string;
{
    Given a boolean, return a string.
}
begin
    if b then Result := 'true' else Result := 'false';
end;

end.