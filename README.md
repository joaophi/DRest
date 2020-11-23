# DRest

Simple delphi framework for http rest server.

Based on [DelphiMVCFramework](https://github.com/danieleteti/delphimvcframework)

JWT implementation taken from [DelphiMVCFramework](https://github.com/danieleteti/delphimvcframework) and modified to support Delphi XEII

Json implementation taken from [JsonDataObjects](https://github.com/ahausladen/JsonDataObjects)

```delphi
unit uExample;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp, ReqMulti, CTA.Rest.Commons, CTA.Rest.Controller;

type

  [Path('/echo')]
  TEchoController = class(TController)
  public
    [Path('/:pText')]
    [Methods([mtGet])]
    procedure Index(pText: String);
  end;

  TRestWebModule = class(TWebModule, IWebRequestHandler)
  private
    function HandleRequest(Request: TWebRequest; Response: TWebResponse): Boolean;
    procedure OnException(Request: TWebRequest; Response: TWebResponse; E: Exception);
  end;

var
  RestWebModuleClass: TComponentClass = TRestWebModule;

implementation

uses
  CTA.Rest.Compress, CTA.Rest.Etag, CTA.Rest.JSON, CTA.Rest.Router;

var
  FRouter: IRouter;

{ TEchoController }

procedure TEchoController.Index(pText: string);
var
  lJson: TJsonObject;
begin
  lJson := TJsonObject.Create;
  try
    lJson['text'] := pText;
    Render(lJson);
  finally
    lJson.Free;
  end;
end;

{ TRestWebModule }

function TRestWebModule.HandleRequest(Request: TWebRequest; Response: TWebResponse): Boolean;
begin
  try
    if not FRouter.Execute(Request, Response) then
      raise EHttpException.Create('Not Found', HTTP_STATUS.NotFound);
  except
    on E: Exception do
      OnException(Request, Response, E);
  end;

  Compress(Request, Response);
  Etag(Request, Response);

  Result := True;
end;

procedure TRestWebModule.OnException(Request: TWebRequest; Response: TWebResponse; E: Exception);
var
  lMessage: string;
  lStatusCode: Integer;
  lResponse: TMemoryStream;
  lJson: TJsonObject;
begin
  lMessage := E.Message;
  lStatusCode := HTTP_STATUS.InternalServerError;

  if E is EHttpException then
    lStatusCode := EHttpException(E).StatusCode
  else if E is EJsonException then
  begin
    lMessage := 'Invalid body';
    lStatusCode := HTTP_STATUS.BadRequest;
  end;

  lResponse := TMemoryStream.Create;
  try
    lJson := TJsonObject.Create;
    try
      lJson['error'] := lMessage;
      lJson.SaveToStream(lResponse);
    finally
      lJson.Free;
    end;

    Response.ContentType := 'application/json; charset=UTF-8';
    Response.ContentStream := lResponse;
    Response.StatusCode := lStatusCode;
  except
    lResponse.Free;
    raise;
  end;
end;

initialization

JsonSerializationConfig.NullConvertsToValueTypes := True;
try
  FRouter := TRouter.Create([]);
except
  on E: Exception do
  begin
{$IFDEF DEBUG}
    ShowException(E, nil);
{$ENDIF}
    raise E;
  end;
end;

end.
```
