unit ledger_file_form;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, transactions;

type

  { TfrmLedgerFile }

  TfrmLedgerFile = class(TForm)
    btSave : TButton;
    dlgSave : TSaveDialog;
    txLedgerFile : TMemo;
    procedure btSaveClick(Sender : TObject);
  private

  public
    procedure showLedger(transactions : TTransactions);
  end;

var
  frmLedgerFile : TfrmLedgerFile;

implementation

uses ledger_writer;

{$R *.lfm}

{ TfrmLedgerFile }

procedure TfrmLedgerFile.btSaveClick(Sender : TObject);
begin
  if dlgSave.Execute then
  begin
    txLedgerFile.Lines.SaveToFile(dlgSave.filename);
  end;
end;

procedure TfrmLedgerFile.showLedger(transactions : TTransactions);
var
  ledgerWriter : TLedgerFileWriter;
begin
  ledgerWriter := TLedgerFileWriter.create;
  txLedgerFile.Lines.clear;
  ledgerWriter.writeTransactions(transactions, txLedgerFile.lines);

  ledgerWriter.free;

  Show;
end;

end.

