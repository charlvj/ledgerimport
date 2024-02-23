unit transactions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type

  { TTransaction }

  TTransaction = class
  private
    _amount : currency;
    _date : TDateTime;
    _inAccount : string;
    _notes : string;
    _outAccount : string;
    _payee : string;
    _reference : string;
    procedure Setamount(AValue : currency);
    procedure Setdate(AValue : TDateTime);
    procedure SetinAccount(AValue : string);
    procedure Setnotes(AValue : string);
    procedure SetoutAccount(AValue : string);
    procedure Setpayee(AValue : string);
    procedure Setreference(AValue : string);
  public
    property date : TDateTime read _date write Setdate;
    property payee : string read _payee write Setpayee;
    property reference : string read _reference write Setreference;
    property amount : currency read _amount write Setamount;
    property inAccount : string read _inAccount write SetinAccount;
    property outAccount : string read _outAccount write SetoutAccount;
    property notes : string read _notes write Setnotes;
  end;

  TTransactions = specialize TFPGList<TTransaction>;


function dateComparitor(const trans1, trans2 : TTransaction) : integer;

implementation

uses
  dateutils;

function dateComparitor(const trans1, trans2 : TTransaction) : integer;
begin
  result := CompareDateTime(trans1.date, trans2.date);
end;

{ TTransaction }

procedure TTransaction.Setamount(AValue : currency);
begin
  if _amount = AValue then Exit;
  _amount := AValue;
end;

procedure TTransaction.Setdate(AValue : TDateTime);
begin
  if _date = AValue then Exit;
  _date := AValue;
end;

procedure TTransaction.SetinAccount(AValue : string);
begin
  if _inAccount = AValue then Exit;
  _inAccount := AValue;
end;

procedure TTransaction.Setnotes(AValue : string);
begin
  if _notes = AValue then Exit;
  _notes := AValue;
end;

procedure TTransaction.SetoutAccount(AValue : string);
begin
  if _outAccount = AValue then Exit;
  _outAccount := AValue;
end;

procedure TTransaction.Setpayee(AValue : string);
begin
  if _payee = AValue then Exit;
  _payee := AValue;
end;

procedure TTransaction.Setreference(AValue : string);
begin
  if _reference = AValue then Exit;
  _reference := AValue;
end;

end.

