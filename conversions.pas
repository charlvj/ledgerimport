unit conversions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

function parseDateTime(str : string) : TDateTime;
function parseAmount(str : string) : currency;
function amountToStr(amount : currency) : string;

implementation

function parseDateTime(str : string) : TDateTime;
begin
  FormatSettings.ShortDateFormat := 'mm/dd/yyyy';
  FormatSettings.DateSeparator := '/';
  result := strToDateTime(str, formatSettings);
end;

function parseAmount(str : string) : currency;
var
  negative : boolean;
begin
  negative := false;
  str := StringReplace(str, '$', '', [rfReplaceAll, rfIgnoreCase]);
  str := StringReplace(str, ',', '', [rfReplaceAll, rfIgnoreCase]);
  if str.StartsWith('(') and str.EndsWith(')') then
  begin
    str := StringReplace(str, '(', '', [rfReplaceAll, rfIgnoreCase]);
    str := StringReplace(str, ')', '', [rfReplaceAll, rfIgnoreCase]);
    negative := true;
  end;
  result := StrToCurr(str);
  if negative then
    result := result * -1;
end;

function amountToStr(amount : currency) : string;
begin
  result := FormatFloat('$#,##0.00', amount);
end;

end.

