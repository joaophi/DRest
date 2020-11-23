unit CTA.Rest.Compress;

interface

uses
  Web.HTTPApp;

procedure Compress(Request: TWebRequest; Response: TWebResponse);

implementation

uses
  System.SysUtils, System.Classes, System.ZLib, System.StrUtils, System.Types;

type
  TCompressionType = (ctNone, ctDeflate, ctGZIP);

const
  COMPRESSION_TYPES: array [TCompressionType] of string = ('none', 'deflate', 'gzip');
  WINDOW_BITS: array [TCompressionType] of Integer = (0, -15, 31);

procedure Compress(Request: TWebRequest; Response: TWebResponse);
var
  lAcceptEncoding: string;
  lEncodings: TStringDynArray;
  lCompressionType: TCompressionType;
  I: Integer;
  lItem: String;
  lMemStream: TMemoryStream;
  lZipStream: TZCompressionStream;
begin
  if (Response.ContentStream = nil) or (Response.ContentStream.Size < 1024) then
    Exit;

  lAcceptEncoding := LowerCase(Trim(string(Request.GetFieldByName('Accept-Encoding'))));
  if lAcceptEncoding = EmptyStr then
    Exit;
  lEncodings := SplitString(lAcceptEncoding, ',');

  lCompressionType := TCompressionType.ctNone;
  for I := 0 to High(lEncodings) do
  begin
    lItem := LowerCase(Trim(lEncodings[I]));
    if lItem = 'gzip' then
    begin
      lCompressionType := TCompressionType.ctGZIP;
      Break;
    end
    else if lItem = 'deflate' then
    begin
      lCompressionType := TCompressionType.ctDeflate;
      Break;
    end;
  end;

  if lCompressionType = TCompressionType.ctNone then
    Exit;

  lMemStream := TMemoryStream.Create;
  try
    lZipStream := TZCompressionStream.Create(lMemStream, TZCompressionLevel.zcMax, WINDOW_BITS[lCompressionType]);
    try
      Response.ContentStream.Position := 0;
      lZipStream.CopyFrom(Response.ContentStream, Response.ContentStream.Size);
    finally
      lZipStream.Free;
    end;

    Response.ContentEncoding := AnsiString(COMPRESSION_TYPES[lCompressionType]);
    Response.ContentStream := lMemStream;
  except
    lMemStream.Free;
    raise;
  end;
end;

end.
