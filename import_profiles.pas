unit import_profiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
  TTransactionDirection = (trIn, trOut);

  PPayeeMapping = ^TPayeeMapping;
  TPayeeMapping = record
    direction : TTransactionDirection;
    payeePattern : string;
    payeeAccount : string;
  end;

  TPayeeMappings = specialize TFPGList<PPayeeMapping>;

  PImportProfile = ^TImportProfile;
  TImportProfile = record
    profileName : string;
    account : string;
    dateColumn : integer;
    payeeColumn : integer;
    notesColumn : integer;
    amountColumn : integer;
    defaultInAccount : string;
    defaultOutAccount : string;
    payeeMappings : TPayeeMappings;
  end;

  TImportProfiles = specialize TFPGList<PImportProfile>;

  { TProfileFile }

  TProfileFile = class
  private
    _profiles : TImportProfiles;
    _filename : string;

    function getProfile(profileName : string) : PImportProfile;
    procedure loadFile;
  public
    property profiles[profileName : string] : PImportProfile read getProfile;

    constructor create(filename : string);
    destructor destroy; override;

    function getProfileNames : TStringArray;
    function newProfile(name : string) : PImportProfile;
    procedure deleteProfile(name : string);
    procedure saveFile;
  end;

function transDirectionAsString(dir : TTransactionDirection) : string;
function transDirectionFromString(dir : string) : TTransactionDirection;

procedure freeMappings(list : TPayeeMappings);

implementation

uses
  fpjson;

function transDirectionAsString(dir : TTransactionDirection) : string;
begin
  case dir of
    trIn: result := 'In';
    trOut: result := 'Out';
  end;
end;

function transDirectionFromString(dir : string) : TTransactionDirection;
begin
  case dir of
    'In': result := trIn;
    'Out': result := trOut;
  end;
end;

procedure freeMappings(list : TPayeeMappings);
var
  mapping : PPayeeMapping;
begin
  if assigned(list) then
  begin
    for mapping in list do
      dispose(mapping);
    list.Clear;
  end;
end;

{ TProfileFile }

procedure TProfileFile.saveFile;
var
  jsonDoc : TJSONObject;
  jsonProfiles, jsonMappings : TJSONArray;
  jsonProfile, jsonMapping : TJSONObject;
  profile : PImportProfile;
  mapping : PPayeeMapping;
  profilesFile : TextFile;
begin
  jsonDoc := TJSONObject.create;
  jsonProfiles := TJSONArray.create;

  for profile in _profiles do
  begin
    jsonProfile := TJSONObject.create;
    jsonProfile.Add('name', profile^.profileName);
    jsonProfile.add('account', profile^.account);
    jsonProfile.add('dateColumn', profile^.dateColumn);
    jsonProfile.add('payeeColumn', profile^.payeeColumn);
    jsonProfile.add('notesColumn', profile^.notesColumn);
    jsonProfile.add('amountColumn', profile^.amountColumn);
    jsonProfile.add('defaultInAccount', profile^.defaultInAccount);
    jsonProfile.add('defaultOutAccount', profile^.defaultOutAccount);

    jsonMappings := TJSONArray.create;
    for mapping in profile^.payeeMappings do
    begin
      jsonMapping := TJSONObject.create;
      jsonMapping.add('direction', transDirectionAsString(mapping^.direction));
      jsonMapping.add('payeePattern', mapping^.payeePattern);
      jsonMapping.add('payeeAccount', mapping^.payeeAccount);

      jsonMappings.add(jsonMapping);
    end;

    jsonProfile.add('payeeMappings', jsonMappings);

    jsonProfiles.add(jsonProfile);
  end;

  jsonDoc.add('profiles', jsonProfiles);

  assignFile(profilesFile, _filename);
  Rewrite(profilesFile);
  try
    writeln(profilesFile, jsonDoc.AsJSON);
  finally
    closeFile(profilesFile);
  end;

  jsonDoc.free;
end;

procedure TProfileFile.loadFile;
var
  fileStream : TFileStream;
  jsonProfileEnum, jsonMappingEnum : TJSONEnum;
  jsonDoc, jsonProfile, jsonMapping : TJSONObject;
  jsonProfiles, jsonMappings : TJSONArray;
  profile : PImportProfile;
  mapping : PPayeeMapping;
  unnamedCounter : integer;
begin
  unnamedCounter := 1;
  fileStream := TFileStream.create(_filename, fmOpenRead);
  try
    jsonDoc := TJSONObject(GetJSON(fileStream));
    try
      jsonProfiles := jsonDoc.Get('profiles', TJSONArray.create);
      for jsonProfileEnum in jsonProfiles do
      begin
        jsonProfile := TJSONObject(jsonProfileEnum.Value);

        new(profile);
        profile^.payeeMappings := TPayeeMappings.create;

        profile^.profileName := jsonProfile.get('name', 'Unnamed');
        if profile^.profileName = 'Unnamed' then
        begin
          profile^.profileName := 'Unnamed ' + IntToStr(unnamedCounter);
          inc(unnamedCounter);
        end;

        profile^.account := jsonProfile.get('account', 'Assets:Unknown');
        profile^.dateColumn := jsonProfile.get('dateColumn', -1);
        profile^.payeeColumn := jsonProfile.get('payeeColumn', -1);
        profile^.notesColumn := jsonProfile.get('notesColumn', -1);
        profile^.amountColumn := jsonProfile.get('amountColumn', -1);
        profile^.defaultInAccount := jsonProfile.get('defaultInAccount', 'Income:Unknown');
        profile^.defaultOutAccount := jsonProfile.get('defaultOutAccount', 'Expenses:Unknown');

        jsonMappings := jsonProfile.get('payeeMappings', TJSONArray.create);
        for jsonMappingEnum in jsonMappings do
        begin
          jsonMapping := TJSONObject(jsonMappingEnum.Value);

          new(mapping);
          mapping^.direction := transDirectionFromString(jsonMapping.get('direction', 'In'));
          mapping^.payeePattern := jsonMapping.get('payeePattern', '');
          mapping^.payeeAccount := jsonMapping.get('payeeAccount', '');

          profile^.payeeMappings.add(mapping);
        end;

        _profiles.add(profile);
      end;
    finally
      jsonDoc.free;
    end;
  finally
    fileStream.free;
  end;
end;

function TProfileFile.getProfile(profileName : string) : PImportProfile;
var
  profile : PImportProfile;
begin
  for profile in _profiles do
  begin
    if profile^.profileName = profileName then
    begin
      result := profile;
      break;
    end;
  end;
end;

constructor TProfileFile.create(filename : string);
begin
  _filename := filename;
  _profiles := TImportProfiles.create;
  if fileExists(_filename) then
    loadFile;
end;

destructor TProfileFile.destroy;
var
  profile : PImportProfile;
  mapping : PPayeeMapping;
begin
  //saveFile;
  for profile in _profiles do
  begin
    for mapping in profile^.payeeMappings do
    begin
      dispose(mapping);
    end;
    profile^.payeeMappings.free;
    dispose(profile);
  end;
  _profiles.free;

  inherited destroy;
end;

function TProfileFile.getProfileNames : TStringArray;
var
  i : integer;
begin
  setLength(result, _profiles.Count);
  for i := 0 to _profiles.count - 1 do
  begin
    result[i] := _profiles[i]^.profileName;
  end;
end;

function TProfileFile.newProfile(name : string) : PImportProfile;
begin
  new(result);
  result^.profileName := name;
  result^.payeeMappings := TPayeeMappings.create;
  _profiles.add(result);
end;

procedure TProfileFile.deleteProfile(name : string);
var
  i, index : integer;
  profile : PImportProfile;
begin
  for i := 0 to _profiles.count - 1 do
  begin
    if _profiles[i]^.profileName = name then
    begin
      profile := _profiles[i];
      index := i;
      break;
    end;
  end;
  _profiles.Delete(index);
  freeMappings(profile^.payeeMappings);
  dispose(profile);
end;

end.

