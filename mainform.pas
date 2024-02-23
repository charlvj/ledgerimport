unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls,
  ComCtrls, Buttons, Menus,
  import_profiles, DividerBevel;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btFilename : TButton;
    btAddPattern : TButton;
    btSaveProfile : TButton;
    btRemovePattern : TButton;
    btCreateLedgerFile : TButton;
    btDeleteProfile : TButton;
    cbProfileNames : TComboBox;
    cbReference : TComboBox;
    DividerBevel1 : TDividerBevel;
    Label11 : TLabel;
    txDefaultOutAccount : TEdit;
    Label10 : TLabel;
    Label8 : TLabel;
    Label9 : TLabel;
    txAccount : TEdit;
    Label7 : TLabel;
    tgHeaderRow : TCheckBox;
    cbDate : TComboBox;
    cbPayee : TComboBox;
    cbNotes : TComboBox;
    cbAmount : TComboBox;
    cbPayeeDir : TComboBox;
    dlgOpenDialog : TOpenDialog;
    txDefaultInAccount : TEdit;
    txPayeePattern : TEdit;
    txPayeeAccount : TEdit;
    GroupBox1 : TGroupBox;
    GroupBox2 : TGroupBox;
    Label2 : TLabel;
    Label3 : TLabel;
    Label4 : TLabel;
    Label5 : TLabel;
    Label6 : TLabel;
    lsPatterns : TListView;
    txFilename : TEdit;
    Label1 : TLabel;
    gridData : TStringGrid;
    procedure btAddPatternClick(Sender : TObject);
    procedure btCreateLedgerFileClick(Sender : TObject);
    procedure btDeleteProfileClick(Sender : TObject);
    procedure btFilenameClick(Sender : TObject);
    procedure btSaveProfileClick(Sender : TObject);
    procedure btRemovePatternClick(Sender : TObject);
    procedure cbProfileNamesChange(Sender : TObject);
    procedure cbProfileNamesSelect(Sender : TObject);
    procedure FormCreate(Sender : TObject);
    procedure tgHeaderRowChange(Sender : TObject);
    procedure tgHeaderRowClick(Sender : TObject);
    procedure txPayeeAccountEnter(Sender : TObject);
    procedure txPayeeAccountExit(Sender : TObject);
    procedure txPayeePatternEnter(Sender : TObject);
    procedure txPayeePatternExit(Sender : TObject);
  private
    _filename : string;
    _profileFile : TProfileFile;
    _currentProfile : PImportProfile;

    procedure importFile;
    procedure displayProfile(profile : PImportProfile);
    procedure assignProfile(profile : PImportProfile);
    procedure parseTransactions;

    procedure Setfilename(AValue : string);
    procedure SetprofileFile(AValue : TProfileFile);
  public
    property filename : string read _filename write Setfilename;
    property profileFile : TProfileFile read _profileFile write SetprofileFile;
  end;

var
  frmMain : TfrmMain;

implementation

uses transactions, conversions, ledger_file_form;

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.txPayeePatternExit(Sender : TObject);
begin
  if txPayeePattern.text = '' then
     txPayeePattern.text := 'Payee Pattern';
end;

procedure TfrmMain.importFile;
var
  col, c, colCount : integer;
  colName : string;
begin
  if dlgOpenDialog.execute then
  begin
    txFilename.text := dlgOpenDialog.filename;
    gridData.Clear;
    gridData.LoadFromCSVFile(txFilename.text, ',', true, 0, true); //, ',', tgHeaderRow.checked);
    gridData.FixedRows := 1;
    gridData.AutoSizeColumns;
  end;
end;

procedure TfrmMain.displayProfile(profile : PImportProfile);
var
  mapping : PPayeeMapping;
  item : TListItem;
begin
  if assigned(profile) then
  begin
    txAccount.text := profile^.account;
    cbDate.ItemIndex := profile^.dateColumn;
    cbPayee.ItemIndex := profile^.payeeColumn;
    cbNotes.ItemIndex := profile^.notesColumn;
    cbReference.ItemIndex := profile^.refColumn;
    cbAmount.ItemIndex := profile^.amountColumn;
    txDefaultInAccount.text := profile^.defaultInAccount;
    txDefaultOutAccount.text := profile^.defaultOutAccount;

    lsPatterns.Clear;
    for mapping in profile^.payeeMappings do
    begin
      item := lsPatterns.Items.Add;
      item.Caption := transDirectionAsString(mapping^.direction);
      item.SubItems.add(mapping^.payeePattern);
      item.SubItems.add(mapping^.payeeAccount);
    end;
  end
  else
  begin
    txAccount.text := '';
    cbDate.ItemIndex := -1;
    cbPayee.ItemIndex := -1;
    cbNotes.ItemIndex := -1;
    cbReference.ItemIndex := -1;
    cbAmount.ItemIndex := -1;
    txDefaultInAccount.text := '';
    txDefaultOutAccount.text := '';

    lsPatterns.Clear;
  end;
end;

procedure TfrmMain.assignProfile(profile : PImportProfile);
var
  item : TListItem;
  mapping : PPayeeMapping;
begin
  profile^.account := txAccount.text;
  profile^.dateColumn := cbDate.ItemIndex;
  profile^.payeeColumn := cbPayee.ItemIndex;
  profile^.notesColumn := cbNotes.ItemIndex;
  profile^.refColumn := cbReference.ItemIndex;
  profile^.amountColumn := cbAmount.ItemIndex;
  profile^.defaultInAccount := txDefaultInAccount.text;
  profile^.defaultOutAccount := txDefaultOutAccount.text;

  freeMappings(profile^.payeeMappings);
  for item in lsPatterns.items do
  begin
    new(mapping);
    mapping^.direction := transDirectionFromString(item.Caption);
    mapping^.payeePattern := item.SubItems[0];
    mapping^.payeeAccount := item.SubItems[1];
    profile^.payeeMappings.add(mapping);
  end;
end;

procedure TfrmMain.parseTransactions;
var
  profile : PImportProfile;
  mapping : PPayeeMapping;
  row, col : integer;
  transactions : TTransactions;
  transaction : TTransaction;
  cellValue : string;
  mappingFound : boolean;
begin
  // We'll build a brand new ImportProfile from the UI in case something
  // was changed in the UI.
  new(profile);
  profile^.profileName := cbProfileNames.text;
  profile^.payeeMappings := TPayeeMappings.create;
  assignProfile(profile);

  // Now we can create the transactions
  transactions := TTransactions.create;
  try
    for row := 1 to gridData.RowCount - 1 do  // row 0 is the header
    begin
      transaction := TTransaction.create;
      transaction.date := parseDateTime(gridData.rows[row][profile^.dateColumn]);
      transaction.payee := gridData.rows[row][profile^.payeeColumn];
      transaction.notes := gridData.rows[row][profile^.notesColumn];
      transaction.reference := gridData.rows[row][profile^.refColumn];
      transaction.amount := parseAmount(gridData.rows[row][profile^.amountColumn]);

      if transaction.amount > 0 then
        transaction.inAccount := profile^.account
      else
        transaction.outAccount := profile^.account;

      mappingFound := false;
      for mapping in profile^.payeeMappings do
      begin
        if transaction.payee.Contains(mapping^.payeePattern)
           and (    (transaction.amount > 0) and (mapping^.direction = trIn)
                 or (transaction.amount < 0) and (mapping^.direction = trOut)) then
        begin
          if (mapping^.direction = trIn) and (transaction.amount > 0) then
            transaction.outAccount := mapping^.payeeAccount
          else if (mapping^.direction = trOut) and (transaction.amount < 0) then
            transaction.inAccount := mapping^.payeeAccount;

          mappingFound := true;
          break;
        end;
      end;

      if not mappingFound then
      begin
        if transaction.amount > 0 then
          transaction.outAccount := profile^.defaultInAccount
        else
          transaction.inAccount := profile^.defaultOutAccount;
      end;

      transactions.add(transaction);
    end;

    transactions.sort(@dateComparitor);

    frmLedgerFile.showLedger(transactions);
  finally
    for transaction in transactions do
      transaction.Free;
    transactions.free;
  end;
end;

procedure TfrmMain.Setfilename(AValue : string);
begin
  if _filename = AValue then Exit;
  _filename := AValue;
end;

procedure TfrmMain.SetprofileFile(AValue : TProfileFile);
begin
  if _profileFile = AValue then Exit;
  _profileFile := AValue;
end;

procedure TfrmMain.btFilenameClick(Sender : TObject);
begin
  importFile;
  tgHeaderRowChange(sender);
end;

procedure TfrmMain.btSaveProfileClick(Sender : TObject);
var
  profileName : string;
begin
  profileName := cbProfileNames.text;
  if profileName = _currentProfile^.profileName then
  begin
    assignProfile(_currentProfile);
  end
  else
  begin
    // A new name was entered in the combobox, so create a new profile
    _currentProfile := _profileFile.newProfile(profileName);
    assignProfile(_currentProfile);
    cbProfileNames.items.add(profileName);
  end;
  _profileFile.saveFile;
end;

procedure TfrmMain.btRemovePatternClick(Sender : TObject);
var
  item : TListItem;
begin
  item := lsPatterns.Selected;

  if assigned(item) then
    item.Delete;
end;

procedure TfrmMain.cbProfileNamesChange(Sender : TObject);
begin

end;

procedure TfrmMain.cbProfileNamesSelect(Sender : TObject);
begin
  _currentProfile := _profileFile.profiles[cbProfileNames.text];
  displayProfile(_currentProfile);
end;

procedure TfrmMain.FormCreate(Sender : TObject);
begin
  filename := 'profiles.json';
  profileFile := TProfileFile.create(filename);
  cbProfileNames.items.AddStrings(profileFile.getProfileNames);
  lsPatterns.Columns[1].AutoSize := true;
  lsPatterns.Columns[1].MinWidth := 40;
end;

procedure TfrmMain.tgHeaderRowChange(Sender : TObject);
var
  c : byte;
  col, colCount : integer;
  colHeaders : array of string;
  colName : string;
begin
  colCount := gridData.ColCount;

  if not tgHeaderRow.checked then
  begin
    setLength(colHeaders, colCount);
    c := ord('A');
    for col := 0 to ColCount - 1 do
    begin
      colHeaders[col] := chr(c);
      inc(c);
    end;
    gridData.InsertRowWithValues(0, colHeaders);
    gridData.FixedRows := 1;
  end
  else if gridData.rows[0][0] = 'A' then
  begin
    gridData.DeleteRow(0);
    gridData.FixedRows := 1;
  end;

  cbDate.items.Clear;
  cbPayee.items.clear;
  cbNotes.items.clear;
  cbReference.items.clear;
  cbAmount.items.clear;
  for col := 0 to colCount - 1 do
  begin
    colName := gridData.cols[col][0];
    cbDate.items.add(colName);
    cbPayee.items.add(colName);
    cbNotes.items.add(colName);
    cbReference.items.add(colName);
    cbAmount.items.add(colName);
  end;

  // redisplay the profile to ensure the columns are set properly
  displayProfile(_currentProfile);
end;

procedure TfrmMain.tgHeaderRowClick(Sender : TObject);
begin

end;

procedure TfrmMain.btAddPatternClick(Sender : TObject);
var
  item : TListItem;
begin
  if (txPayeePattern.text <> 'Payee Pattern') and (txPayeeAccount.text <> 'Account') then
  begin
    item := lsPatterns.Items.Add;
    item.Caption := cbPayeeDir.Text;
    item.SubItems.add(txPayeePattern.text);
    item.SubItems.add(txPayeeAccount.text);

    txPayeePattern.text := '';
    txPayeeAccount.text := '';
  end;
end;

procedure TfrmMain.btCreateLedgerFileClick(Sender : TObject);
begin
  parseTransactions;
end;

procedure TfrmMain.btDeleteProfileClick(Sender : TObject);
var
  profileName : string;
  index : integer;
begin
  profileName := cbProfileNames.Text;
  index := cbProfileNames.items.indexOf(profileName);
  _profileFile.deleteProfile(profileName);
  cbProfileNames.Items.Delete(index);

  _profileFile.saveFile;

  if cbProfileNames.items.count > 0 then
    cbProfileNames.text := cbProfileNames.items[0];

  cbProfileNamesSelect(sender);
end;

procedure TfrmMain.txPayeeAccountEnter(Sender : TObject);
begin
  if txPayeeAccount.text = 'Account' then
     txPayeeAccount.text := '';
end;

procedure TfrmMain.txPayeeAccountExit(Sender : TObject);
begin
  if txPayeeAccount.text = '' then
     txPayeeAccount.text := 'Account';
end;

procedure TfrmMain.txPayeePatternEnter(Sender : TObject);
begin
  if txPayeePattern.Text = 'Payee Pattern' then
     txPayeePattern.text := '';
end;

end.

