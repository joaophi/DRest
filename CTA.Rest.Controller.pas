unit CTA.Rest.Controller;

interface

uses
  Web.HTTPApp, CTA.Rest.JSON, System.Classes, Data.DB;

type
  TControllerClazz = class of TController;

  TController = class abstract
  private
    FRequest: TWebRequest;
    FResponse: TWebResponse;
  protected
    procedure Render(AStream: TStream; AContentType: String); overload;
    procedure Render(AStream: TFileStream); overload;
    procedure Render(AObject: TJsonBaseObject; AOwns: Boolean = True); overload;
    procedure Render(ACDS: TDataSet; AOwns: Boolean = True); overload;
    procedure Render204NoContent;

    property Request: TWebRequest read FRequest;
    property Response: TWebResponse read FResponse;
  public
    constructor Create(ARequest: TWebRequest; AResponse: TWebResponse);

    procedure OnBeforeAction(const AActionName: string; var AHandled: Boolean); virtual;
    procedure OnAfterAction(const AActionName: string); virtual;
  end;

implementation

uses
  CTA.Rest.Commons, System.SysUtils, Data.SqlTimSt, System.Variants, System.TypInfo, IdGlobalProtocols;

{ TController }

constructor TController.Create(ARequest: TWebRequest; AResponse: TWebResponse);
begin
  FRequest := ARequest;
  FResponse := AResponse;
end;

procedure TController.OnBeforeAction(const AActionName: string; var AHandled: Boolean);
begin
end;

procedure TController.OnAfterAction(const AActionName: string);
begin
end;

procedure TController.Render(AStream: TStream; AContentType: String);
begin
  Response.ContentType := AnsiString(AContentType);
  Response.ContentStream := AStream;
end;

procedure TController.Render(AStream: TFileStream);
var
  lMimeTable: TIdMimeTable;
begin
  lMimeTable := TIdMimeTable.Create;
  try
    Render(AStream, lMimeTable.GetFileMIMEType(AStream.FileName));
  finally
    lMimeTable.Free;
  end
end;

procedure TController.Render(AObject: TJsonBaseObject; AOwns: Boolean);
var
  lResponse: TMemoryStream;
begin
  try
    lResponse := TMemoryStream.Create;
    try
      AObject.SaveToStream(lResponse);
      Render(lResponse, 'application/json; charset=UTF-8');
    except
      lResponse.Free;
      raise;
    end;
  finally
    if AOwns then
      AObject.Free;
  end;
end;

procedure TController.Render(ACDS: TDataSet; AOwns: Boolean);

  procedure ConvertField(AResult: TJsonObject; const AName: string; AField: TField);
  begin
    if AField.IsNull then
      AResult[AName] := Null
    else
      case AField.DataType of
        ftBoolean:
          AResult.B[AName] := AField.AsBoolean;

        ftInteger, ftSmallint, ftShortint, ftByte, ftWord:
          AResult.I[AName] := AField.AsInteger;

        ftLargeint, ftAutoInc, ftLongword:
          AResult.L[AName] := AField.AsLargeInt;

        Data.DB.ftSingle, ftFloat:
          AResult.F[AName] := AField.AsFloat;

        ftString, ftMemo:
          AResult.S[AName] := AField.AsString;

        ftWideString, ftWideMemo:
          AResult.S[AName] := AField.AsWideString;

        ftDate:
          AResult.S[AName] := FormatDateTime('yyyy-mm-dd', AField.AsDateTime);

        ftDateTime:
          AResult.S[AName] := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', AField.AsDateTime);

        ftTime:
          AResult.S[AName] := SQLTimeStampToStr('hh:nn:ss', AField.AsSQLTimeStamp);

        ftTimeStamp:
          AResult.S[AName] := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', SQLTimeStampToDateTime(AField.AsSQLTimeStamp));

        ftCurrency:
          AResult.F[AName] := AField.AsCurrency;
      else
        raise Exception.CreateFmt('Invalid field type %s', [GetEnumName(TypeInfo(TFieldType), Integer(AField.DataType))]);
      end;
  end;

var
  lArray: TJsonArray;
  lObject: TJsonObject;
  lNames: array of string;
  I: Integer;
begin
  try
    ACDS.DisableControls;
    ACDS.First;
    lArray := TJsonArray.Create;
    try
      lArray.Capacity := ACDS.RecordCount;
      if not ACDS.Eof then
      begin
        lObject := lArray.AddObject;
        lObject.Capacity := ACDS.FieldCount;

        SetLength(lNames, ACDS.FieldCount);
        for I := 0 to ACDS.FieldCount - 1 do
        begin
          lNames[I] := LowerCase(ACDS.Fields[I].FieldName);
          ConvertField(lObject, lNames[I], ACDS.Fields[I]);
        end;

        ACDS.Next;
      end;

      while not ACDS.Eof do
      begin
        lObject := lArray.AddObject;
        lObject.Capacity := ACDS.FieldCount;

        for I := 0 to ACDS.FieldCount - 1 do
          ConvertField(lObject, lNames[I], ACDS.Fields[I]);

        ACDS.Next;
      end;

      Render(lArray, False);
    finally
      lArray.Free;
    end;
  finally
    if AOwns then
      ACDS.Free;
  end;
end;

procedure TController.Render204NoContent;
begin
  Response.StatusCode := HTTP_STATUS.NoContent;
  Response.ContentType := '';
  Response.ContentStream := TNullStream.Create;
end;

end.
