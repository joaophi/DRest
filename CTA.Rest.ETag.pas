unit CTA.Rest.ETag;

interface

uses
  Web.HTTPApp;

procedure ETag(Request: TWebRequest; Response: TWebResponse);

implementation

uses
  System.Classes, IdHashMessageDigest, CTA.Rest.Commons, System.SysUtils;

function HashStream(Stream: TStream): string;
var
  lMD5: TIdHashMessageDigest5;
begin
  lMD5 := TIdHashMessageDigest5.Create;
  try
    Result := lMD5.HashStreamAsHex(Stream);
  finally
    lMD5.Free;
  end;
end;

procedure ETag(Request: TWebRequest; Response: TWebResponse);
var
  lETag: string;
  lRequestETag: string;
begin
  if (Response.ContentStream = nil) then
    Exit;

  Response.ContentStream.Position := 0;
  lETag := HashStream(Response.ContentStream);
  Response.SetCustomHeader('ETag', lETag);

  lRequestETag := string(Request.GetFieldByName('If-None-Match'));

  if (lETag <> '') and (lRequestETag = lETag) then
  begin
    Response.StatusCode := HTTP_STATUS.NotModified;
    Response.ContentType := '';
    Response.ContentStream := TNullStream.Create;
  end;
end;

end.
