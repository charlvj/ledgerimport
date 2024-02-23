unit ledger_writer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, transactions;

type

  { TLedgerFileWriter }

  TLedgerFileWriter = class
  public
    procedure writeTransaction(transaction : TTransaction; lines : TStrings);
    procedure writeTransactions(transactions : TTransactions; lines : TStrings);
  end;

implementation

uses
  conversions;

{ TLedgerFileWriter }

procedure TLedgerFileWriter.writeTransaction(transaction : TTransaction;
  lines : TStrings);
var
  amount : currency;
begin
  amount := abs(transaction.amount);
  lines.add(format('%s  (%s)  %s', [formatDateTime('YYYY/MM/DD', transaction.date), transaction.reference, transaction.payee]));
  if transaction.notes <> '' then
    lines.add(format('    ; %s', [transaction.notes]));
  lines.add(format('    %-40s        %s', [transaction.inAccount, amountToStr(amount)]));
  lines.add(format('    %-40s        %s', [transaction.outAccount, amountToStr(-amount)]));
end;

procedure TLedgerFileWriter.writeTransactions(transactions : TTransactions;
  lines : TStrings);
var
  transaction : TTransaction;
begin
  for transaction in transactions do
  begin
    writeTransaction(transaction, lines);
    lines.add('');
  end;
end;

end.

