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
    cbAmountNegative : TComboBox;
    DividerBevel1 : TDividerBevel;
    Label11 : TLabel;
    Label12 : TLabel;
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
    procedure cbAmount1Change(Sender : TObject);
    procedure cbDateChange(Sender : TObject);
    procedure cbProfileNamesSelect(Sender : TObject);
    procedure FormCreate(Sender : TObject);
    procedure Label5Click(Sender : TObject);
    procedure tgHeaderRowChange(Sender : TObject);
    procedure txFilenameKeyPress(Sender : TObject; var Key : char);
    procedure txPayeeAccountEnter(Sender : TObject);
    procedure txPayeeAccountExit(Sender : TObject);
    procedure txPayeePatternEnter(Sender : TObject);
    procedure txPayeePatternExit(Sender : TObject);
  private
    _filename : string;
    _profileFile : TProfileFile;
    _currentProfile : PImportProfile;

    procedure importFile(filename : string);
    procedure displayProfile(profile : PImportProfile);
    procedure assignProfile(profile : PImportProfile);
    procedure parseTransactions;
    function substituteVariables(const s : string; const values : TStringArray) : string;

    procedure Setfilename(AValue : string);
    procedure SetprofileFile(AValue : TProfileFile);
  public
    property filename : string read _filename write Setfilename;
    property profileFile : TProfileFile read _profileFile write SetprofileFile;
  end;

var
  frmMain : TfrmMain;

implementation

uses strutils, transactions, conversions, ledger_file_form;

{$R *.lfm}

procedure comboClear(cb : TComboBox);
begin
  cb.Clear;
  cb.Items.add('None');
end;

procedure comboAdd(cb : TComboBox; s : string);
begin

end;

function comboGetIndex(cb : TComboBox) : integer;
begin
  if cb.itemIndex = -1 then
    result := -1
  else
    result := cb.itemIndex - 1;
end;

procedure comboSetIndex(cb : TComboBox; itemIndex : integer);
begin
  if itemIndex = -1 then
    cb.itemIndex := -1
  else
    cb.itemIndex := itemIndex + 1;
end;


{ TfrmMain }

procedure TfrmMain.txPayeePatternExit(Sender : TObject);
begin
  if txPayeePattern.text = '' then
     txPayeePattern.text := 'Payee Pattern';
end;

procedure TfrmMain.importFile(filename : string);
begin
  gridData.Clear;
  gridData.LoadFromCSVFile(filename, ',', true, 0, true);
  gridData.FixedRows := 1;
  gridData.AutoSizeColumns;
end;

procedure TfrmMain.displayProfile(profile : PImportProfile);
var
  mapping : PPayeeMapping;
  item : TListItem;
begin
  if assigned(profile) then
  begin
    txAccount.text := profile^.account;
    comboSetIndex(cbDate, profile^.dateColumn);
    comboSetIndex(cbPayee, profile^.payeeColumn);
    comboSetIndex(cbNotes, profile^.notesColumn);
    comboSetIndex(cbReference, profile^.refColumn);
    comboSetIndex(cbAmount, profile^.amountColumn);
    comboSetIndex(cbAmountNegative, profile^.amountNegativeColumn);
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
  profile^.dateColumn := comboGetIndex(cbDate);
  profile^.payeeColumn := comboGetIndex(cbPayee);
  profile^.notesColumn := comboGetIndex(cbNotes);
  profile^.refColumn := comboGetIndex(cbReference);
  profile^.amountColumn := comboGetIndex(cbAmount);
  profile^.amountNegativeColumn := comboGetIndex(cbAmountNegative);
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
  mappingFound : boolean;
  columnValues : TStringArray;
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

      if transaction.amount = 0 then
      begin
        // Check the amountNegativeColumn
        transaction.amount := -1 * abs(parseAmount(gridData.rows[row][profile^.amountNegativeColumn]));
      end;

      // If it is a liability account we must negate the amount
      if StartsStr('Liabilities', profile^.account) then
         transaction.amount := -1 * transaction.amount;

      setLength(columnValues, gridData.colCount * 2);
      for col := 0 to gridData.ColCount - 1 do
      begin
        columnValues[col * 2] := gridData.rows[0][col];
        columnValues[col * 2 + 1] := gridData.rows[row][col];
      end;

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
            transaction.outAccount := substituteVariables(mapping^.payeeAccount, columnValues)
          else if (mapping^.direction = trOut) and (transaction.amount < 0) then
            transaction.inAccount := substituteVariables(mapping^.payeeAccount, columnValues);

          mappingFound := true;
          break;
        end;
      end;

      if not mappingFound then
      begin
        if transaction.amount > 0 then
          transaction.outAccount := substituteVariables(profile^.defaultInAccount, columnValues)
        else
          transaction.inAccount := substituteVariables(profile^.defaultOutAccount, columnValues);
      end;

      setLength(columnValues, 0);

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

function TfrmMain.substituteVariables(const s : string; const values : TStringArray) : string;
  function getColumnValue(const colName : string) : string;
  var
    c : integer;
  begin
    result := '';
    for c := 0 to gridData.ColCount - 1 do
    begin
      if gridData.rows[0][c] = colName then
      begin
        result := gridData.rows[0][c];
        break;
      end;
    end;
  end;

  function getValue(const varName : string) : string;
  var i : integer;
  begin
    for i := low(values) to high(values) div 2 do
    begin
      if values[i * 2] = varName then
      begin
        result := values[i * 2 + 1];
        break;
      end;
    end;
  end;

var
  c : integer;
  v : string;
begin
  // We can definitely make this more efficient
  result := s;
  for c := 0 to gridData.ColCount - 1 do
  begin
    v := '${' + gridData.rows[0][c] + '}';
    if pos(v, result) > 0 then
       result := replaceText(result, v, getValue(gridData.rows[0][c]));
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
  if dlgOpenDialog.execute then
  begin
    txFilename.text := dlgOpenDialog.filename;
    importFile(dlgOpenDialog.filename);
    tgHeaderRowChange(sender);
  end;
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

procedure TfrmMain.cbAmount1Change(Sender : TObject);
begin

end;

procedure TfrmMain.cbDateChange(Sender : TObject);
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

procedure TfrmMain.Label5Click(Sender : TObject);
begin

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

  comboClear(cbDate);
  comboClear(cbPayee);
  comboClear(cbNotes);
  comboClear(cbReference);
  comboClear(cbAmount);
  comboClear(cbAmountNegative);
  for col := 0 to colCount - 1 do
  begin
    colName := gridData.cols[col][0];
    cbDate.items.add(colName);
    cbPayee.items.add(colName);
    cbNotes.items.add(colName);
    cbReference.items.add(colName);
    cbAmount.items.add(colName);
    cbAmountNegative.items.add(colName);
  end;

  // redisplay the profile to ensure the columns are set properly
  displayProfile(_currentProfile);
end;

procedure TfrmMain.txFilenameKeyPress(Sender : TObject; var Key : char);
begin
  if key = #13 then
  begin
    importFile(txFilename.Text);
    key := #0;
  end;
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

